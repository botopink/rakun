%%% rakun-data — the SQL host: the connection pool, the three driver arms
%%% (ETS, PostgreSQL, MySQL) and the local transaction. Front 08.
%%%
%%% WHAT LIVES HERE AND WHY. botopink has no top-level mutable state and no
%%% processes of its own, and a pool IS processes: a supervisor, N connection
%%% processes each owning one connection, a free list and a monitor per borrower.
%%% So the pool is the host's. What is NOT here is everything a reader would
%%% want to change: which URL selects which arm, the named-parameter rewriting
%%% (`:name` -> `$1` / `?`), the refusal texts for a missing or unused
%%% parameter, `single`'s cardinality rule, `Row.int`'s coercion, the
%%% `#[query]` checks and the `<Type>Tx` proxy. Those are botopink, in
%%% `src/datasource.bp` and `src/sql/*.bp`.
%%%
%%% MODULE ATOM. `rakun_sql`, never `sql` or `datasource`: `shipErlSidecars`
%%% silently skips a qualifier that matches a module the build emitted.
%%%
%%% ONE MODULE, THREE CALLBACK ROLES. The supervisor (`rakun_pool_sup`) and the
%%% connection processes are both implemented here, because a sidecar ships as
%%% one `.erl` per `#[@External.Erlang]` atom. `init/1` dispatches on its
%%% argument: `pool_sup` answers the supervisor spec, `{conn, Ds, Slot}` the
%%% connection state. No `-behaviour` attribute is declared for either, so the
%%% two callback sets do not warn about each other.
%%%
%%% TABLE AND SUPERVISOR OWNERSHIP. An ETS table dies with its creating process
%%% and a supervisor started with `start_link` dies with its parent. Both are
%%% created by one owner process that does nothing but stay alive, registered
%%% under a name so a second caller losing the race finds everything already
%%% there (`rakun_chain`'s shape). A test process that starts a pool and exits
%%% therefore does not take the pool with it.
%%%
%%% THE POOL. A slot row `{{Ds, Slot}, Pid, free | leased, Borrower}` per
%%% connection. A checkout CLAIMS a free row with `ets:select_replace/2` — an
%%% atomic compare-and-swap on the row, so two callers never lease the same
%%% connection — and then tells the connection who holds it, so the connection
%%% monitors the borrower. A borrower that dies is a `'DOWN'` in the connection
%%% process: it rolls back any open transaction and frees its own row. There is
%%% no reclaim sweep and no test-on-borrow: a connection process either exists
%%% or it does not, and the supervisor restarts one that died, whose `init/1`
%%% rewrites its slot row with the new pid.
%%%
%%% THE ETS ARM. A real, small store, not a mock: one ETS row per table,
%%% `{{Ds, Table}, Columns, Rows}`, and a statement is parsed here (the subset in
%%% `exec_ets/3`) and applied under a per-datasource lock. A transaction is
%%% snapshot-and-restore: `begin` copies the datasource's tables, `rollback`
%%% puts the copy back, `commit` drops it. That is atomic (both statements or
%%% neither) and it is NOT isolated: a second connection writing while a
%%% transaction is open is overwritten by that transaction's rollback. The
%%% README's scope note says the arm is the subset a test uses, and this is the
%%% part of that sentence that matters.
-module(rakun_sql).
-compile(nowarn_deprecated_catch).

%% the datasource and the pool
-export([start_pool/6, stop_pool/1, pool_started/1, pool_stats/1,
         kill_slot/2, settle/2, driver_loadable/1, set_reachable/2]).
%% statements and transactions
-export([exec/3, tx_run/3, tx_open/1, with_rollback/2, spawn_borrower/3,
         drop_all/1]).
%% the statement log, the query registry, boot warnings
-export([log/1, log_lines/0, log_reset/0, log_on/0, log_off/0, ds_arm/1,
         register_query/2, registered_queries/0,
         warn/1, warnings/0, warnings_reset/0]).
%% supervisor + gen_server callbacks and their start functions
-export([init/1, start_conn/2, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
%% reachable for a test or a later front
-export([ensure/0, owner/1, sleep/1]).

-define(OWNER, rakun_sql_owner).
-define(SUP, rakun_pool_sup).
-define(DS, rakun_sql_ds).          %% set:         {Ds, Arm, Url, Size, TimeoutMs}
-define(SLOTS, rakun_sql_slots).    %% set:         {{Ds, Slot}, Pid, free | leased, Borrower}
-define(CTR, rakun_sql_ctr).        %% set:         {{Ds, Counter}, N}
-define(DATA, rakun_sql_data).      %% set:         {{Ds, Table}, Columns, Rows}
-define(AVAIL, rakun_sql_avail).    %% set:         {Ds, true | false}  (ETS arm only)
-define(LOG, rakun_sql_log).        %% ordered_set: {Seq, Line}
-define(QUERIES, rakun_sql_queries).%% ordered_set: {Seq, Name, Sql}
-define(WARN, rakun_sql_warn).      %% ordered_set: {Seq, Line}
-define(TXKEY(Ds), {rakun_sql_tx, Ds}).

%% ═══ lifecycle ═══════════════════════════════════════════════════════════════

ensure() ->
    case whereis(?OWNER) of
        undefined -> boot();
        _ -> ok
    end.

boot() ->
    Caller = self(),
    Pid = spawn(fun() -> owner(Caller) end),
    Ref = erlang:monitor(process, Pid),
    receive
        {?OWNER, ready} -> erlang:demonitor(Ref, [flush]), ok;
        {'DOWN', Ref, process, Pid, _} -> ok
    after 5000 ->
        erlang:demonitor(Ref, [flush]), ok
    end.

owner(Caller) ->
    case catch erlang:register(?OWNER, self()) of
        true ->
            Common = [named_table, public],
            _ = ets:new(?DS, [set | Common]),
            _ = ets:new(?SLOTS, [set | Common]),
            _ = ets:new(?CTR, [set | Common]),
            _ = ets:new(?DATA, [set | Common]),
            _ = ets:new(?AVAIL, [set | Common]),
            _ = ets:new(?LOG, [ordered_set | Common]),
            _ = ets:new(?QUERIES, [ordered_set | Common]),
            _ = ets:new(?WARN, [ordered_set | Common]),
            process_flag(trap_exit, true),
            {ok, _Sup} = supervisor:start_link({local, ?SUP}, ?MODULE, pool_sup),
            Caller ! {?OWNER, ready},
            owner_loop();
        _ ->
            Caller ! {?OWNER, ready},
            ok
    end.

owner_loop() ->
    receive
        stop -> ok;
        _ -> owner_loop()
    end.

sleep(Ms) -> timer:sleep(Ms), 0.

%% ═══ supervisor and connection callbacks ════════════════════════════════════
%% The restart intensity is generous on purpose: a connection that dies is
%% restarted with a fresh connection, and a suite that kills connections to
%% prove it must not exhaust the supervisor.

init(pool_sup) ->
    {ok, {#{strategy => one_for_one, intensity => 1000, period => 1}, []}};
init({conn, Ds, Slot}) ->
    process_flag(trap_exit, true),
    true = ets:insert(?SLOTS, {{Ds, Slot}, self(), free, none}),
    {ok, #{ds => Ds, slot => Slot, conn => none, borrower => none, mref => none,
           tx => none}}.

start_conn(Ds, Slot) ->
    gen_server:start_link(?MODULE, {conn, Ds, Slot}, []).

handle_call({lease, Borrower}, _From, S) ->
    case connect(S) of
        {ok, S1} ->
            Ref = erlang:monitor(process, Borrower),
            {reply, ok, S1#{borrower => Borrower, mref => Ref}};
        {error, Reason} ->
            free_row(S),
            {reply, {error, Reason}, S}
    end;
handle_call(release, _From, S) ->
    S1 = abandon_tx(S),
    {reply, ok, free(S1)};
handle_call(connect, _From, S) ->
    case connect(S) of
        {ok, S1} -> {reply, ok, S1};
        {error, Reason} -> {reply, {error, Reason}, S}
    end;
handle_call({exec, Sql, Params}, _From, S) ->
    {reply, run(S, Sql, Params), S};
handle_call('begin', _From, S) ->
    case tx_begin(S) of
        {ok, S1} -> {reply, ok, S1};
        {error, R} -> {reply, {error, R}, S}
    end;
handle_call(commit, _From, S) ->
    case tx_commit(S) of
        {ok, S1} -> {reply, ok, S1};
        {error, R} -> {reply, {error, R}, abandon_tx(S)}
    end;
handle_call(rollback, _From, S) ->
    {reply, ok, abandon_tx(S)};
handle_call(_Other, _From, S) ->
    {reply, {error, <<"rakun-data: unknown connection request">>}, S}.

handle_cast(_Msg, S) -> {noreply, S}.

%% The borrower died while holding this connection: roll back whatever it had
%% open and put the connection back. This is the only reclaim path.
handle_info({'DOWN', Ref, process, _Pid, _Reason}, S = #{mref := Ref}) ->
    S1 = abandon_tx(S),
    bump(maps:get(ds, S), reclaimed),
    {noreply, free(S1)};
handle_info(_Msg, S) -> {noreply, S}.

terminate(_Reason, S) ->
    _ = abandon_tx(S),
    disconnect(S),
    ok.

code_change(_Old, S, _Extra) -> {ok, S}.

free(S = #{mref := Ref}) ->
    case Ref of
        none -> ok;
        _ -> erlang:demonitor(Ref, [flush])
    end,
    free_row(S),
    S#{borrower => none, mref => none}.

free_row(#{ds := Ds, slot := Slot}) ->
    true = ets:insert(?SLOTS, {{Ds, Slot}, self(), free, none}).

%% ═══ the datasource ══════════════════════════════════════════════════════════
%% `start_pool/6` answers `<<>>` or the refusal text. `Eager` connects every
%% slot before answering (`bootstrap-mode=eager`); otherwise each connection
%% opens on its first lease. A second start of the same datasource replaces the
%% pool: the old children are stopped first, so a reconfigured test never
%% leases a connection built for the previous URL.

start_pool(Ds, Arm, Url, Size, TimeoutMs, Eager) ->
    ensure(),
    _ = stop_pool(Ds),
    true = ets:insert(?DS, {Ds, Arm, Url, Size, TimeoutMs}),
    [true = ets:insert(?CTR, {{Ds, C}, 0}) || C <- [checkouts, waiting, opened, reclaimed, peak]],
    Started = [supervisor:start_child(?SUP, #{id => {Ds, I},
                                              start => {?MODULE, start_conn, [Ds, I]},
                                              restart => permanent,
                                              type => worker})
               || I <- lists:seq(1, Size)],
    case [R || {error, R} <- Started] of
        [] when Eager -> connect_all(Ds);
        [] -> <<>>;
        [First | _] ->
            _ = stop_pool(Ds),
            iolist_to_binary(io_lib:format("rakun-data: the pool for datasource '~s' did not start: ~p", [Ds, First]))
    end.

connect_all(Ds) ->
    Pids = [P || {{D, _}, P, _, _} <- ets:tab2list(?SLOTS), D =:= Ds],
    Failures = [R || P <- Pids, {error, R} <- [gen_server:call(P, connect, infinity)]],
    case Failures of
        [] -> <<>>;
        [R | _] ->
            _ = stop_pool(Ds),
            R
    end.

stop_pool(Ds) ->
    ensure(),
    Ids = [Id || {Id = {D, _}, _, _, _} <- supervisor:which_children(?SUP), D =:= Ds],
    lists:foreach(fun(Id) ->
                          _ = supervisor:terminate_child(?SUP, Id),
                          _ = supervisor:delete_child(?SUP, Id)
                  end, Ids),
    ets:match_delete(?SLOTS, {{Ds, '_'}, '_', '_', '_'}),
    ets:delete(?DS, Ds),
    length(Ids).

pool_started(Ds) ->
    ensure(),
    ets:member(?DS, Ds).

%% Size is read from the SUPERVISOR, not from a counter: a connection process
%% the supervisor has not restarted yet is not part of the pool.
pool_stats(Ds) ->
    ensure(),
    Alive = [P || {{D, _}, P, _, _} <- supervisor:which_children(?SUP), D =:= Ds, is_pid(P),
                  is_process_alive(P)],
    Rows = [R || R = {{D, _}, P, _, _} <- ets:tab2list(?SLOTS), D =:= Ds, lists:member(P, Alive)],
    Busy = length([x || {_, _, leased, _} <- Rows]),
    #{size => length(Alive),
      busy => Busy,
      free => length(Rows) - Busy,
      waiting => counter(Ds, waiting),
      checkouts => counter(Ds, checkouts),
      opened => counter(Ds, opened),
      reclaimed => counter(Ds, reclaimed),
      peak => counter(Ds, peak)}.

kill_slot(Ds, Slot) ->
    ensure(),
    case ets:lookup(?SLOTS, {Ds, Slot}) of
        [{_, Pid, _, _}] -> exit(Pid, kill), 1;
        [] -> 0
    end.

%% Wait (at most `Ms`) until every connection of the pool is alive and free,
%% and answer how many are. The observation a test makes after killing a
%% connection or a borrower; the pool keeps no counter for it.
settle(Ds, Ms) ->
    Deadline = erlang:monotonic_time(millisecond) + Ms,
    settle_loop(Ds, Deadline).

settle_loop(Ds, Deadline) ->
    #{size := Size, free := Free} = pool_stats(Ds),
    Want = case ets:lookup(?DS, Ds) of [{_, _, _, N, _}] -> N; [] -> 0 end,
    Done = Size =:= Want andalso Free =:= Want,
    case Done orelse erlang:monotonic_time(millisecond) >= Deadline of
        true -> Free;
        false -> timer:sleep(5), settle_loop(Ds, Deadline)
    end.

counter(Ds, C) ->
    case ets:lookup(?CTR, {Ds, C}) of
        [{_, N}] -> N;
        [] -> 0
    end.

bump(Ds, C) -> ets:update_counter(?CTR, {Ds, C}, {2, 1}, {{Ds, C}, 0}).
drop(Ds, C) -> ets:update_counter(?CTR, {Ds, C}, {2, -1}, {{Ds, C}, 0}).

driver_loadable(Module) ->
    case code:ensure_loaded(binary_to_atom(Module, utf8)) of
        {module, _} -> true;
        _ -> false
    end.

%% The ETS arm's "database is down" switch. An ETS store cannot be unreachable,
%% so without it `bootstrap-mode=eager` failing the boot would be untestable
%% with no external database; a connection opened while it is off fails the way
%% a refused socket would.
set_reachable(Ds, Up) ->
    ensure(),
    true = ets:insert(?AVAIL, {Ds, Up}),
    0.

%% ═══ checkout / checkin ══════════════════════════════════════════════════════

checkout(Ds) ->
    case ets:lookup(?DS, Ds) of
        [] ->
            {error, iolist_to_binary(io_lib:format("rakun-data: datasource '~s' has no pool - call dataSourceBoot() or startDataSource(...) first", [Ds]))};
        [{_, _, _, Size, TimeoutMs}] ->
            Deadline = erlang:monotonic_time(millisecond) + TimeoutMs,
            checkout_loop(Ds, Size, TimeoutMs, Deadline, false)
    end.

checkout_loop(Ds, Size, TimeoutMs, Deadline, Waiting) ->
    case claim(Ds, ets:match(?SLOTS, {{Ds, '$1'}, '$2', free, '_'})) of
        {ok, Pid} ->
            unwait(Ds, Waiting),
            case catch gen_server:call(Pid, {lease, self()}, infinity) of
                ok ->
                    bump(Ds, checkouts),
                    note_peak(Ds),
                    {ok, Pid};
                {error, Reason} -> {error, Reason};
                {'EXIT', _} -> checkout_loop(Ds, Size, TimeoutMs, Deadline, false)
            end;
        none ->
            case erlang:monotonic_time(millisecond) >= Deadline of
                true ->
                    unwait(Ds, Waiting),
                    {error, iolist_to_binary(io_lib:format(
                        "rakun-data: no connection available from datasource '~s' within ~b ms (pool size ~b, all in use) - raise rakun.datasource.pool.size or rakun.datasource.pool.connection-timeout",
                        [Ds, TimeoutMs, Size]))};
                false ->
                    W = case Waiting of true -> true; false -> bump(Ds, waiting), true end,
                    timer:sleep(2),
                    checkout_loop(Ds, Size, TimeoutMs, Deadline, W)
            end
    end.

unwait(_Ds, false) -> ok;
unwait(Ds, true) -> drop(Ds, waiting), ok.

note_peak(Ds) ->
    Busy = length(ets:match(?SLOTS, {{Ds, '_'}, '_', leased, '_'})),
    case Busy > counter(Ds, peak) of
        true -> ets:insert(?CTR, {{Ds, peak}, Busy});
        false -> ok
    end.

claim(_Ds, []) -> none;
claim(Ds, [[Slot, Pid] | Rest]) ->
    Key = {Ds, Slot},
    Spec = [{{'$1', '$2', free, '_'},
             [{'=:=', '$1', {const, Key}}, {'=:=', '$2', {const, Pid}}],
             [{{'$1', '$2', leased, {const, self()}}}]}],
    case ets:select_replace(?SLOTS, Spec) of
        1 ->
            case is_process_alive(Pid) of
                true -> {ok, Pid};
                false -> claim(Ds, Rest)
            end;
        _ -> claim(Ds, Rest)
    end.

checkin(Pid) ->
    _ = (catch gen_server:call(Pid, release, infinity)),
    ok.

%% ═══ statements ══════════════════════════════════════════════════════════════
%% `exec/3` answers the record `SqlOutcome` as a map. It does NOT raise: the
%% raising `query` and the `@Result` `tryQuery` are both decided in botopink
%% from this one answer, so they cannot disagree about what failed.
%%
%% LAZY ACQUISITION. This is the only place a connection is checked out outside
%% a transaction, and it runs when a statement runs — never when a template or
%% a repository is constructed.

exec(Ds, Sql, Params) ->
    ensure(),
    Outcome = case get(?TXKEY(Ds)) of
                  Pid when is_pid(Pid) -> call_exec(Pid, Sql, Params);
                  _ ->
                      case checkout(Ds) of
                          {ok, Pid} ->
                              try call_exec(Pid, Sql, Params) after checkin(Pid) end;
                          {error, R} -> {error, R}
                      end
              end,
    outcome(Outcome).

call_exec(Pid, Sql, Params) ->
    case catch gen_server:call(Pid, {exec, Sql, Params}, infinity) of
        {'EXIT', Reason} ->
            {error, iolist_to_binary(io_lib:format("rakun-data: the connection died during the statement: ~p", [Reason]))};
        Other -> Other
    end.

outcome({ok, {rows, Cols, Rows}}) ->
    #{ok => true, error => <<>>, columns => Cols,
      rows => [[cell(V) || V <- R] || R <- Rows], count => length(Rows)};
outcome({ok, {count, N}}) ->
    #{ok => true, error => <<>>, columns => [], rows => [], count => N};
outcome({error, Reason}) ->
    #{ok => false, error => to_bin(Reason), columns => [], rows => [], count => 0}.

cell(null) -> <<>>;
cell(V) -> to_bin(V).

to_bin(B) when is_binary(B) -> B;
to_bin(I) when is_integer(I) -> integer_to_binary(I);
to_bin(F) when is_float(F) -> float_to_binary(F, [short]);
to_bin(A) when is_atom(A) -> atom_to_binary(A, utf8);
to_bin(L) when is_list(L) ->
    try iolist_to_binary(L) catch _:_ -> iolist_to_binary(io_lib:format("~p", [L])) end;
to_bin(T) -> iolist_to_binary(io_lib:format("~p", [T])).

%% ═══ transactions ════════════════════════════════════════════════════════════
%% The open transaction is a mark in the CALLING process's dictionary: every
%% statement that process issues against the same datasource finds the marked
%% connection instead of checking out a second one. A `tx_run` that finds the
%% mark JOINS it (REQUIRED propagation): the thunk runs and nothing else
%% happens — one begin and one commit for the whole nest.

tx_run(Ds, _Label, Fun) ->
    ensure(),
    case get(?TXKEY(Ds)) of
        Pid when is_pid(Pid) -> Fun();
        _ -> tx_new(Ds, Fun, commit)
    end.

tx_open(Ds) -> is_pid(get(?TXKEY(Ds))).

%% A transaction that is ALWAYS rolled back — the test isolation: two test
%% blocks each wrapped in one never see each other's rows.
with_rollback(Ds, Fun) ->
    ensure(),
    case get(?TXKEY(Ds)) of
        Pid when is_pid(Pid) -> Fun();
        _ -> tx_new(Ds, Fun, rollback)
    end.

tx_new(Ds, Fun, Ending) ->
    Pid = case checkout(Ds) of
              {ok, P} -> P;
              {error, R} -> erlang:error({panic, R})
          end,
    case gen_server:call(Pid, 'begin', infinity) of
        ok -> ok;
        {error, BeginErr} ->
            checkin(Pid),
            erlang:error({panic, to_bin(BeginErr)})
    end,
    _ = log(<<"begin">>),
    put(?TXKEY(Ds), Pid),
    try Fun() of
        Value ->
            erase(?TXKEY(Ds)),
            case Ending of
                commit ->
                    case gen_server:call(Pid, commit, infinity) of
                        ok ->
                            _ = log(<<"commit">>),
                            checkin(Pid),
                            Value;
                        {error, CommitErr} ->
                            _ = log(<<"rollback">>),
                            checkin(Pid),
                            erlang:error({panic, to_bin(CommitErr)})
                    end;
                rollback ->
                    ok = gen_server:call(Pid, rollback, infinity),
                    _ = log(<<"rollback">>),
                    checkin(Pid),
                    Value
            end
    catch
        Class:Reason:Stack ->
            erase(?TXKEY(Ds)),
            _ = (catch gen_server:call(Pid, rollback, infinity)),
            _ = log(<<"rollback">>),
            checkin(Pid),
            erlang:raise(Class, Reason, Stack)
    end.

%% A borrower that dies mid-query, for the pool's reclaim test: a process that
%% checks out, opens a transaction, runs one statement and is then KILLED —
%% no `after`, no rollback of its own. Answers once the statement has run.
spawn_borrower(Ds, Sql, Params) ->
    ensure(),
    Me = self(),
    Ref = make_ref(),
    Pid = spawn(fun() ->
                        {ok, Conn} = checkout(Ds),
                        ok = gen_server:call(Conn, 'begin', infinity),
                        Out = call_exec(Conn, Sql, Params),
                        Me ! {Ref, Out},
                        receive never -> ok end
                end),
    receive
        {Ref, _Out} -> exit(Pid, kill), 1
    after 5000 -> exit(Pid, kill), 0
    end.

drop_all(Ds) ->
    ensure(),
    ets:match_delete(?DATA, {{Ds, '_'}, '_', '_'}),
    0.

%% ═══ the log, the registry, the warnings ═════════════════════════════════════

%% The statement log is OFF until a caller turns it on: an application that
%% never reads it must not grow a table with every statement it ever ran.
log(Line) ->
    ensure(),
    case ets:lookup(?CTR, log_enabled) of
        [{_, 1}] -> true = ets:insert(?LOG, {erlang:unique_integer([monotonic]), Line});
        _ -> ok
    end,
    0.

log_on() -> ensure(), true = ets:insert(?CTR, {log_enabled, 1}), 0.
log_off() -> ensure(), true = ets:insert(?CTR, {log_enabled, 0}), 0.

ds_arm(Ds) ->
    ensure(),
    {Arm, _Url} = arm_of(Ds),
    Arm.

log_lines() ->
    ensure(),
    [L || {_, L} <- ets:tab2list(?LOG)].

log_reset() ->
    ensure(),
    true = ets:delete_all_objects(?LOG),
    0.

register_query(Name, Sql) ->
    ensure(),
    true = ets:insert(?QUERIES, {erlang:unique_integer([monotonic]), Name, Sql}),
    0.

registered_queries() ->
    ensure(),
    [<<N/binary, " ", S/binary>> || {_, N, S} <- ets:tab2list(?QUERIES)].

warn(Line) ->
    ensure(),
    true = ets:insert(?WARN, {erlang:unique_integer([monotonic]), Line}),
    io:format(standard_error, "~s~n", [Line]),
    0.

warnings() ->
    ensure(),
    [L || {_, L} <- ets:tab2list(?WARN)].

warnings_reset() ->
    ensure(),
    true = ets:delete_all_objects(?WARN),
    0.

%% ═══ the arms: connect, run, transactions ═══════════════════════════════════

arm_of(Ds) ->
    case ets:lookup(?DS, Ds) of
        [{_, Arm, Url, _, _}] -> {Arm, Url};
        [] -> {<<"none">>, <<>>}
    end.

connect(S = #{conn := none, ds := Ds}) ->
    {Arm, Url} = arm_of(Ds),
    case open(Arm, Ds, Url) of
        {ok, C} ->
            bump(Ds, opened),
            {ok, S#{conn => C}};
        {error, R} -> {error, R}
    end;
connect(S) -> {ok, S}.

open(<<"ets">>, Ds, _Url) ->
    case ets:lookup(?AVAIL, Ds) of
        [{_, false}] ->
            {error, iolist_to_binary(io_lib:format("rakun-data: datasource '~s' is unreachable (the ETS store is marked down)", [Ds]))};
        _ -> {ok, ets}
    end;
open(<<"postgresql">>, Ds, Url) ->
    Opts = url_opts(Url),
    try apply(epgsql, connect, [maps:from_list(Opts)]) of
        {ok, C} -> {ok, {pg, C}};
        {error, R} -> {error, unreachable(Ds, Url, R)}
    catch _:R -> {error, unreachable(Ds, Url, R)}
    end;
open(<<"mysql">>, Ds, Url) ->
    Opts = url_opts(Url),
    MOpts = [{host, binary_to_list(proplists:get_value(host, Opts, <<"localhost">>))},
             {port, proplists:get_value(port, Opts, 3306)},
             {user, binary_to_list(proplists:get_value(username, Opts, <<>>))},
             {password, binary_to_list(proplists:get_value(password, Opts, <<>>))},
             {database, binary_to_list(proplists:get_value(database, Opts, <<>>))}],
    try apply(mysql, start_link, [MOpts]) of
        {ok, C} -> unlink(C), {ok, {my, C}};
        {error, R} -> {error, unreachable(Ds, Url, R)}
    catch _:R -> {error, unreachable(Ds, Url, R)}
    end;
open(Arm, Ds, _Url) ->
    {error, iolist_to_binary(io_lib:format("rakun-data: datasource '~s' has no driver arm '~s'", [Ds, Arm]))}.

unreachable(Ds, Url, R) ->
    iolist_to_binary(io_lib:format("rakun-data: datasource '~s' at '~s' is unreachable: ~p", [Ds, redact(Url), R])).

%% A URL in a message never carries its password: `user:***@host`.
redact(Url) ->
    case binary:split(Url, <<"://">>) of
        [Scheme, Rest] ->
            case binary:split(Rest, <<"@">>) of
                [Auth, Host] ->
                    User = hd(binary:split(Auth, <<":">>)),
                    <<Scheme/binary, "://", User/binary, ":***@", Host/binary>>;
                _ -> Url
            end;
        _ -> Url
    end.

%% `scheme://user:password@host:port/database` — the parts a driver needs.
url_opts(Url) ->
    Rest0 = case binary:split(Url, <<"://">>) of [_, R] -> R; _ -> Url end,
    {Auth, Rest1} = case binary:split(Rest0, <<"@">>) of [A, R1] -> {A, R1}; [R1] -> {<<>>, R1} end,
    {User, Pass} = case binary:split(Auth, <<":">>) of [U, P] -> {U, P}; [U] -> {U, <<>>} end,
    {HostPort, Db} = case binary:split(Rest1, <<"/">>) of [H, D] -> {H, D}; [H] -> {H, <<>>} end,
    {Host, Port} = case binary:split(HostPort, <<":">>) of
                       [Hn, Pn] -> {Hn, binary_to_integer(Pn)};
                       [Hn] -> {Hn, 5432}
                   end,
    [{host, Host}, {port, Port}, {username, User}, {password, Pass}, {database, Db}].

disconnect(#{conn := {pg, C}}) -> catch apply(epgsql, close, [C]), ok;
disconnect(#{conn := {my, C}}) -> catch apply(mysql, stop, [C]), ok;
disconnect(_) -> ok.

run(#{conn := none}, _Sql, _Params) ->
    {error, <<"rakun-data: the connection is not open">>};
run(#{conn := ets, ds := Ds}, Sql, Params) ->
    exec_ets(Ds, Sql, Params);
run(#{conn := {pg, C}}, Sql, Params) ->
    case catch apply(epgsql, equery, [C, Sql, Params]) of
        {ok, Cols, Rows} -> {ok, {rows, [element(2, Col) || Col <- Cols], [tuple_to_list(R) || R <- Rows]}};
        {ok, N} when is_integer(N) -> {ok, {count, N}};
        {ok, N, _Cols, _Rows} -> {ok, {count, N}};
        {error, E} -> {error, to_bin(io_lib:format("~p", [E]))};
        Other -> {error, to_bin(io_lib:format("~p", [Other]))}
    end;
run(#{conn := {my, C}}, Sql, Params) ->
    case catch apply(mysql, query, [C, Sql, Params]) of
        ok -> {ok, {count, apply(mysql, affected_rows, [C])}};
        {ok, Cols, Rows} -> {ok, {rows, Cols, Rows}};
        {error, E} -> {error, to_bin(io_lib:format("~p", [E]))};
        Other -> {error, to_bin(io_lib:format("~p", [Other]))}
    end.

tx_begin(S = #{tx := none, conn := ets, ds := Ds}) ->
    Snap = ets:match_object(?DATA, {{Ds, '_'}, '_', '_'}),
    {ok, S#{tx => {snapshot, Snap}}};
tx_begin(S = #{tx := none, conn := {_, _}}) ->
    case run(S, <<"BEGIN">>, []) of
        {ok, _} -> {ok, S#{tx => open}};
        {error, R} -> {error, R}
    end;
tx_begin(#{tx := none}) -> {error, <<"rakun-data: the connection is not open">>};
tx_begin(_S) -> {error, <<"rakun-data: a transaction is already open on this connection">>}.

tx_commit(S = #{tx := {snapshot, _}}) -> {ok, S#{tx => none}};
tx_commit(S = #{tx := open}) ->
    case run(S, <<"COMMIT">>, []) of
        {ok, _} -> {ok, S#{tx => none}};
        {error, R} -> {error, R}
    end;
tx_commit(S) -> {ok, S}.

abandon_tx(S = #{tx := {snapshot, Snap}, ds := Ds}) ->
    locked(Ds, fun() ->
                       ets:match_delete(?DATA, {{Ds, '_'}, '_', '_'}),
                       true = ets:insert(?DATA, Snap)
               end),
    S#{tx => none};
abandon_tx(S = #{tx := open}) ->
    _ = run(S, <<"ROLLBACK">>, []),
    S#{tx => none};
abandon_tx(S) -> S.

locked(Ds, Fun) ->
    global:trans({{rakun_sql_db, Ds}, self()}, Fun, [node()]).

%% ═══ the ETS arm: the supported subset ═══════════════════════════════════════
%%   CREATE TABLE [IF NOT EXISTS] t (col type ..., ...)
%%   DROP TABLE [IF EXISTS] t
%%   INSERT INTO t [(cols)] VALUES (v, ...)[, (v, ...)]
%%   SELECT * | col [AS a], ... | COUNT(*) [AS a] FROM t
%%          [WHERE p] [ORDER BY col [ASC|DESC], ...] [LIMIT n]
%%   SELECT <literal>                        (the liveness statement)
%%   UPDATE t SET col = v, ... [WHERE p]
%%   DELETE FROM t [WHERE p]
%%   CALL rakun_sleep(ms)                    (holds the connection, not the store)
%% where `p` is `operand (= | <> | !=) operand` joined by AND / OR, with
%% parentheses; an operand is a column, `$N`, a quoted string, a number or NULL.
%% Anything else is `{error, "... unsupported construct 'X' ..."}` — never an
%% empty result.

exec_ets(Ds, Sql, Params) ->
    try
        Toks = tokens(Sql),
        Stmt = parse(strip_semi(Toks), Sql),
        case Stmt of
            {sleep, V} ->
                timer:sleep(binary_to_integer(value(V, Params))),
                {ok, {count, 0}};
            {literal_select, Items} ->
                {ok, {rows, [to_bin(L) || {lit, L} <- Items], [[L || {lit, L} <- Items]]}};
            _ ->
                locked(Ds, fun() -> apply_stmt(Ds, Stmt, Params) end)
        end
    catch
        throw:{sql_error, Msg} -> {error, Msg}
    end.

fail(Fmt, Args) -> throw({sql_error, iolist_to_binary(io_lib:format(Fmt, Args))}).

unsupported(What, Sql) ->
    fail("rakun-data ets arm: unsupported construct '~s' in: ~s", [What, Sql]).

strip_semi(Toks) ->
    case lists:reverse(Toks) of
        [{sym, $;} | R] -> lists:reverse(R);
        _ -> Toks
    end.

%% ── tokens ──

tokens(Sql) -> tok(Sql, []).

tok(<<>>, Acc) -> lists:reverse(Acc);
tok(<<C, R/binary>>, Acc) when C =:= $\s; C =:= $\t; C =:= $\n; C =:= $\r -> tok(R, Acc);
tok(<<$', R/binary>>, Acc) ->
    {S, R1} = quoted(R, <<>>),
    tok(R1, [{str, S} | Acc]);
tok(<<$", R/binary>>, Acc) ->
    case binary:split(R, <<"\"">>) of
        [Id, R1] -> tok(R1, [{word, Id} | Acc]);
        _ -> fail("rakun-data ets arm: unterminated quoted identifier", [])
    end;
tok(<<$$, R/binary>>, Acc) ->
    {D, R1} = digits(R, <<>>),
    case D of
        <<>> -> fail("rakun-data ets arm: '$' not followed by a parameter number", []);
        _ -> tok(R1, [{param, binary_to_integer(D)} | Acc])
    end;
tok(<<"<>", R/binary>>, Acc) -> tok(R, [{op, <<"<>">>} | Acc]);
tok(<<"!=", R/binary>>, Acc) -> tok(R, [{op, <<"<>">>} | Acc]);
tok(<<"<=", R/binary>>, Acc) -> tok(R, [{op, <<"<=">>} | Acc]);
tok(<<">=", R/binary>>, Acc) -> tok(R, [{op, <<">=">>} | Acc]);
tok(<<C, R/binary>>, Acc) when C >= $0, C =< $9 ->
    {D, R1} = digits(R, <<C>>),
    tok(R1, [{num, D} | Acc]);
tok(<<$-, C, R/binary>>, Acc) when C >= $0, C =< $9 ->
    {D, R1} = digits(R, <<$-, C>>),
    tok(R1, [{num, D} | Acc]);
tok(<<C, R/binary>>, Acc) when (C >= $a andalso C =< $z); (C >= $A andalso C =< $Z); C =:= $_ ->
    {W, R1} = word(R, <<C>>),
    tok(R1, [{word, W} | Acc]);
tok(<<C, R/binary>>, Acc) when C =:= $(; C =:= $); C =:= $,; C =:= $*; C =:= $=; C =:= $;; C =:= $.; C =:= $<; C =:= $>; C =:= $+; C =:= $- ->
    tok(R, [{sym, C} | Acc]);
tok(<<C, _/binary>>, _Acc) ->
    fail("rakun-data ets arm: unsupported character '~c'", [C]).

quoted(<<$', $', R/binary>>, Acc) -> quoted(R, <<Acc/binary, $'>>);
quoted(<<$', R/binary>>, Acc) -> {Acc, R};
quoted(<<C, R/binary>>, Acc) -> quoted(R, <<Acc/binary, C>>);
quoted(<<>>, _Acc) -> fail("rakun-data ets arm: unterminated string literal", []).

digits(<<C, R/binary>>, Acc) when C >= $0, C =< $9 -> digits(R, <<Acc/binary, C>>);
digits(R, Acc) -> {Acc, R}.

word(<<C, R/binary>>, Acc) when (C >= $a andalso C =< $z); (C >= $A andalso C =< $Z); (C >= $0 andalso C =< $9); C =:= $_ ->
    word(R, <<Acc/binary, C>>);
word(R, Acc) -> {Acc, R}.

up(B) -> string:uppercase(B).
low(B) -> string:lowercase(B).

kw({word, W}, K) -> up(W) =:= K;
kw(_, _) -> false.

expect([T | R], K, Sql) ->
    case kw(T, K) of
        true -> R;
        false -> unsupported(show(T), Sql)
    end;
expect([], K, Sql) -> fail("rakun-data ets arm: expected ~s at the end of: ~s", [K, Sql]).

expect_sym([{sym, C} | R], C, _Sql) -> R;
expect_sym([T | _], C, Sql) -> fail("rakun-data ets arm: expected '~c' but found '~s' in: ~s", [C, show(T), Sql]);
expect_sym([], C, Sql) -> fail("rakun-data ets arm: expected '~c' at the end of: ~s", [C, Sql]).

ident([{word, W} | R], _Sql) -> {low(W), R};
ident([T | _], Sql) -> unsupported(show(T), Sql);
ident([], Sql) -> fail("rakun-data ets arm: expected a name at the end of: ~s", [Sql]).

show({word, W}) -> up(W);
show({str, S}) -> <<"'", S/binary, "'">>;
show({num, N}) -> N;
show({param, N}) -> <<"$", (integer_to_binary(N))/binary>>;
show({op, O}) -> O;
show({sym, C}) -> <<C>>.

done([], _Sql) -> ok;
done([T | _], Sql) -> unsupported(show(T), Sql).

%% ── statements ──

parse([], Sql) -> fail("rakun-data ets arm: empty statement: ~s", [Sql]);
parse([T | R] = All, Sql) ->
    case show(T) of
        <<"CREATE">> -> parse_create(R, Sql);
        <<"DROP">> -> parse_drop(R, Sql);
        <<"INSERT">> -> parse_insert(R, Sql);
        <<"SELECT">> -> parse_select(R, Sql);
        <<"UPDATE">> -> parse_update(R, Sql);
        <<"DELETE">> -> parse_delete(R, Sql);
        <<"CALL">> -> parse_call(R, Sql);
        _ -> unsupported(show(hd(All)), Sql)
    end.

parse_create(R0, Sql) ->
    R1 = expect(R0, <<"TABLE">>, Sql),
    {IfNot, R2} = case R1 of
                      [A, B, C | Rr] ->
                          case kw(A, <<"IF">>) andalso kw(B, <<"NOT">>) andalso kw(C, <<"EXISTS">>) of
                              true -> {true, Rr};
                              false -> {false, R1}
                          end;
                      _ -> {false, R1}
                  end,
    {Name, R3} = ident(R2, Sql),
    R4 = expect_sym(R3, $(, Sql),
    {Defs, R5} = until_close(R4, 0, [], [], Sql),
    done(R5, Sql),
    Cols = [low(W) || [{word, W} | _] <- Defs, not constraint(W)],
    {create, Name, Cols, IfNot}.

constraint(W) -> lists:member(up(W), [<<"PRIMARY">>, <<"UNIQUE">>, <<"CONSTRAINT">>, <<"FOREIGN">>, <<"CHECK">>]).

%% The token groups between a `(` already consumed and its matching `)`,
%% split at top-level commas.
until_close([{sym, $)} | R], 0, Cur, Acc, _Sql) -> {lists:reverse([lists:reverse(Cur) | Acc]), R};
until_close([{sym, $)} = T | R], D, Cur, Acc, Sql) -> until_close(R, D - 1, [T | Cur], Acc, Sql);
until_close([{sym, $(} = T | R], D, Cur, Acc, Sql) -> until_close(R, D + 1, [T | Cur], Acc, Sql);
until_close([{sym, $,} | R], 0, Cur, Acc, Sql) -> until_close(R, 0, [], [lists:reverse(Cur) | Acc], Sql);
until_close([T | R], D, Cur, Acc, Sql) -> until_close(R, D, [T | Cur], Acc, Sql);
until_close([], _D, _Cur, _Acc, Sql) -> fail("rakun-data ets arm: unbalanced parentheses in: ~s", [Sql]).

parse_drop(R0, Sql) ->
    R1 = expect(R0, <<"TABLE">>, Sql),
    {IfExists, R2} = case R1 of
                         [A, B | Rr] ->
                             case kw(A, <<"IF">>) andalso kw(B, <<"EXISTS">>) of
                                 true -> {true, Rr};
                                 false -> {false, R1}
                             end;
                         _ -> {false, R1}
                     end,
    {Name, R3} = ident(R2, Sql),
    done(R3, Sql),
    {drop, Name, IfExists}.

parse_insert(R0, Sql) ->
    R1 = expect(R0, <<"INTO">>, Sql),
    {Name, R2} = ident(R1, Sql),
    {Cols, R3} = case R2 of
                     [{sym, $(} | Rc] ->
                         {Groups, Rc1} = until_close(Rc, 0, [], [], Sql),
                         {[single_ident(G, Sql) || G <- Groups], Rc1};
                     _ -> {all, R2}
                 end,
    R4 = expect(R3, <<"VALUES">>, Sql),
    {Tuples, R5} = value_tuples(R4, [], Sql),
    done(R5, Sql),
    {insert, Name, Cols, Tuples}.

single_ident([{word, W}], _Sql) -> low(W);
single_ident([T | _], Sql) -> unsupported(show(T), Sql);
single_ident([], Sql) -> fail("rakun-data ets arm: empty column list in: ~s", [Sql]).

value_tuples(R0, Acc, Sql) ->
    R1 = expect_sym(R0, $(, Sql),
    {Groups, R2} = until_close(R1, 0, [], [], Sql),
    Vals = [single_value(G, Sql) || G <- Groups],
    case R2 of
        [{sym, $,} | R3] -> value_tuples(R3, [Vals | Acc], Sql);
        _ -> {lists:reverse([Vals | Acc]), R2}
    end.

single_value([T], Sql) -> operand(T, Sql);
single_value([T | _], Sql) -> unsupported(show(T), Sql);
single_value([], Sql) -> fail("rakun-data ets arm: empty value in: ~s", [Sql]).

operand({param, N}, _Sql) -> {param, N};
operand({str, S}, _Sql) -> {lit, S};
operand({num, N}, _Sql) -> {lit, N};
operand({word, W} = T, Sql) ->
    case up(W) of
        <<"NULL">> -> {lit, null};
        <<"TRUE">> -> {lit, <<"true">>};
        <<"FALSE">> -> {lit, <<"false">>};
        _ ->
            case keyword(W) of
                true -> unsupported(show(T), Sql);
                false -> {col, low(W)}
            end
    end;
operand(T, Sql) -> unsupported(show(T), Sql).

keyword(W) ->
    lists:member(up(W), [<<"SELECT">>, <<"FROM">>, <<"WHERE">>, <<"AND">>, <<"OR">>, <<"ORDER">>,
                         <<"BY">>, <<"LIMIT">>, <<"JOIN">>, <<"GROUP">>, <<"HAVING">>, <<"UNION">>,
                         <<"LIKE">>, <<"IN">>, <<"IS">>, <<"NOT">>, <<"BETWEEN">>, <<"AS">>,
                         <<"ON">>, <<"SET">>, <<"VALUES">>, <<"INTO">>, <<"OFFSET">>, <<"DISTINCT">>]).

parse_select(R0, Sql) ->
    {Items, R1} = projection(R0, [], Sql),
    case R1 of
        [] ->
            case lists:all(fun({lit, _}) -> true; (_) -> false end, Items) of
                true -> {literal_select, Items};
                false -> fail("rakun-data ets arm: SELECT without FROM may only select literals: ~s", [Sql])
            end;
        _ ->
            R2 = expect(R1, <<"FROM">>, Sql),
            {Name, R3} = ident(R2, Sql),
            {Where, R4} = where(R3, Sql),
            {Order, R5} = order_by(R4, Sql),
            {Limit, R6} = limit(R5, Sql),
            done(R6, Sql),
            {select, Name, Items, Where, Order, Limit}
    end.

projection([{sym, $*} | R], [], _Sql) -> {[star], R};
projection(R0, Acc, Sql) ->
    {Item, R1} = proj_item(R0, Sql),
    {Named, R2} = case R1 of
                      [A, {word, Alias} | Rr] ->
                          case kw(A, <<"AS">>) of
                              true -> {alias(Item, Alias), Rr};
                              false -> {Item, R1}
                          end;
                      _ -> {Item, R1}
                  end,
    case R2 of
        [{sym, $,} | R3] -> projection(R3, [Named | Acc], Sql);
        _ -> {lists:reverse([Named | Acc]), R2}
    end.

proj_item([{word, W}, {sym, $(}, {sym, $*}, {sym, $)} | R], Sql) ->
    case up(W) of
        <<"COUNT">> -> {{count, <<"count">>}, R};
        Other -> unsupported(Other, Sql)
    end;
proj_item([{word, W}, {sym, $(} | _], Sql) -> unsupported(up(W), Sql);
proj_item([{word, W} = T | R], Sql) ->
    case keyword(W) of
        true -> unsupported(show(T), Sql);
        false -> {{col, low(W), low(W)}, R}
    end;
proj_item([{num, N} | R], _Sql) -> {{lit, N}, R};
proj_item([{str, S} | R], _Sql) -> {{lit, S}, R};
proj_item([T | _], Sql) -> unsupported(show(T), Sql);
proj_item([], Sql) -> fail("rakun-data ets arm: SELECT with nothing to select: ~s", [Sql]).

alias({count, _}, A) -> {count, A};
alias({col, C, _}, A) -> {col, C, A};
alias(Other, _A) -> Other.

where([T | R], Sql) ->
    case kw(T, <<"WHERE">>) of
        true -> or_expr(R, Sql);
        false -> {true, [T | R]}
    end;
where([], _Sql) -> {true, []}.

or_expr(R0, Sql) ->
    {L, R1} = and_expr(R0, Sql),
    case R1 of
        [T | R2] ->
            case kw(T, <<"OR">>) of
                true -> {Rt, R3} = or_expr(R2, Sql), {{'or', L, Rt}, R3};
                false -> {L, R1}
            end;
        [] -> {L, []}
    end.

and_expr(R0, Sql) ->
    {L, R1} = pred(R0, Sql),
    case R1 of
        [T | R2] ->
            case kw(T, <<"AND">>) of
                true -> {Rt, R3} = and_expr(R2, Sql), {{'and', L, Rt}, R3};
                false -> {L, R1}
            end;
        [] -> {L, []}
    end.

pred([{sym, $(} | R0], Sql) ->
    {E, R1} = or_expr(R0, Sql),
    {E, expect_sym(R1, $), Sql)};
pred([A, {sym, $=}, B | R], Sql) -> {{eq, operand(A, Sql), operand(B, Sql)}, R};
pred([A, {op, <<"<>">>}, B | R], Sql) -> {{ne, operand(A, Sql), operand(B, Sql)}, R};
pred([_A, Op | _], Sql) -> unsupported(show(Op), Sql);
pred([T | _], Sql) -> unsupported(show(T), Sql);
pred([], Sql) -> fail("rakun-data ets arm: WHERE with no predicate: ~s", [Sql]).

order_by([A, B | R], Sql) ->
    case kw(A, <<"ORDER">>) andalso kw(B, <<"BY">>) of
        true -> order_keys(R, [], Sql);
        false -> {[], [A, B | R]}
    end;
order_by(R, _Sql) -> {[], R}.

order_keys(R0, Acc, Sql) ->
    {Col, R1} = ident(R0, Sql),
    {Dir, R2} = case R1 of
                    [T | Rr] ->
                        case show(T) of
                            <<"ASC">> -> {asc, Rr};
                            <<"DESC">> -> {desc, Rr};
                            _ -> {asc, R1}
                        end;
                    [] -> {asc, []}
                end,
    case R2 of
        [{sym, $,} | R3] -> order_keys(R3, [{Col, Dir} | Acc], Sql);
        _ -> {lists:reverse([{Col, Dir} | Acc]), R2}
    end.

limit([T, {num, N} | R], _Sql) ->
    case kw(T, <<"LIMIT">>) of
        true -> {binary_to_integer(N), R};
        false -> {none, [T, {num, N} | R]}
    end;
limit([T, {param, N} | R], _Sql) ->
    case kw(T, <<"LIMIT">>) of
        true -> {{param, N}, R};
        false -> {none, [T, {param, N} | R]}
    end;
limit(R, _Sql) -> {none, R}.

parse_update(R0, Sql) ->
    {Name, R1} = ident(R0, Sql),
    R2 = expect(R1, <<"SET">>, Sql),
    {Sets, R3} = assignments(R2, [], Sql),
    {Where, R4} = where(R3, Sql),
    done(R4, Sql),
    {update, Name, Sets, Where}.

assignments([{word, C}, {sym, $=}, V | R], Acc, Sql) ->
    Acc1 = [{low(C), operand(V, Sql)} | Acc],
    case R of
        [{sym, $,} | R1] -> assignments(R1, Acc1, Sql);
        _ -> {lists:reverse(Acc1), R}
    end;
assignments([T | _], _Acc, Sql) -> unsupported(show(T), Sql);
assignments([], _Acc, Sql) -> fail("rakun-data ets arm: SET with no assignment: ~s", [Sql]).

parse_delete(R0, Sql) ->
    R1 = expect(R0, <<"FROM">>, Sql),
    {Name, R2} = ident(R1, Sql),
    {Where, R3} = where(R2, Sql),
    done(R3, Sql),
    {delete, Name, Where}.

parse_call([{word, W}, {sym, $(}, V, {sym, $)} | R], Sql) ->
    done(R, Sql),
    case low(W) of
        <<"rakun_sleep">> -> {sleep, operand(V, Sql)};
        _ -> unsupported(<<"CALL ", (low(W))/binary>>, Sql)
    end;
parse_call(_R, Sql) -> unsupported(<<"CALL">>, Sql).

%% ── execution ──

value({param, N}, Params) when N >= 1, N =< length(Params) -> lists:nth(N, Params);
value({param, N}, Params) ->
    fail("rakun-data ets arm: parameter $~b is not bound (~b bound)", [N, length(Params)]);
value({lit, L}, _Params) -> L.

table(Ds, Name) ->
    case ets:lookup(?DATA, {Ds, Name}) of
        [{_, Cols, Rows}] -> {Cols, Rows};
        [] -> fail("rakun-data ets arm: no table '~s'", [Name])
    end.

col_index(Col, Cols, Table) ->
    case index_of(Col, Cols, 1) of
        0 -> fail("rakun-data ets arm: table '~s' has no column '~s'", [Table, Col]);
        I -> I
    end.

index_of(_X, [], _I) -> 0;
index_of(X, [X | _], I) -> I;
index_of(X, [_ | T], I) -> index_of(X, T, I + 1).

apply_stmt(Ds, {create, Name, Cols, IfNot}, _Params) ->
    case ets:member(?DATA, {Ds, Name}) of
        true when IfNot -> {ok, {count, 0}};
        true -> fail("rakun-data ets arm: table '~s' already exists", [Name]);
        false ->
            true = ets:insert(?DATA, {{Ds, Name}, Cols, []}),
            {ok, {count, 0}}
    end;
apply_stmt(Ds, {drop, Name, IfExists}, _Params) ->
    case ets:member(?DATA, {Ds, Name}) of
        true -> ets:delete(?DATA, {Ds, Name}), {ok, {count, 0}};
        false when IfExists -> {ok, {count, 0}};
        false -> fail("rakun-data ets arm: no table '~s'", [Name])
    end;
apply_stmt(Ds, {insert, Name, Cols0, Tuples}, Params) ->
    {Cols, Rows} = table(Ds, Name),
    Target = case Cols0 of all -> Cols; _ -> Cols0 end,
    Idx = [col_index(C, Cols, Name) || C <- Target],
    New = [begin
               case length(T) =:= length(Target) of
                   true -> ok;
                   false -> fail("rakun-data ets arm: INSERT into '~s' names ~b columns and gives ~b values", [Name, length(Target), length(T)])
               end,
               Pairs = lists:zip(Idx, [value(V, Params) || V <- T]),
               [proplists:get_value(I, Pairs, null) || I <- lists:seq(1, length(Cols))]
           end || T <- Tuples],
    true = ets:insert(?DATA, {{Ds, Name}, Cols, Rows ++ New}),
    {ok, {count, length(New)}};
apply_stmt(Ds, {select, Name, Items, Where, Order, Limit}, Params) ->
    {Cols, Rows} = table(Ds, Name),
    Hit = [R || R <- Rows, holds(Where, R, Cols, Name, Params)],
    Sorted = sort_rows(Order, Hit, Cols, Name),
    Limited = case Limit of
                  none -> Sorted;
                  {param, _} = P -> lists:sublist(Sorted, binary_to_integer(value(P, Params)));
                  N -> lists:sublist(Sorted, N)
              end,
    case Items of
        [{count, Alias}] -> {ok, {rows, [Alias], [[integer_to_binary(length(Limited))]]}};
        [star] -> {ok, {rows, Cols, Limited}};
        _ ->
            Proj = [case It of
                        {col, C, A} -> {A, col_index(C, Cols, Name)};
                        {count, _} -> fail("rakun-data ets arm: COUNT(*) beside other columns needs GROUP BY, which is not supported", []);
                        {lit, _} -> fail("rakun-data ets arm: a literal beside columns is not supported", [])
                    end || It <- Items],
            {ok, {rows, [A || {A, _} <- Proj], [[lists:nth(I, R) || {_, I} <- Proj] || R <- Limited]}}
    end;
apply_stmt(Ds, {update, Name, Sets, Where}, Params) ->
    {Cols, Rows} = table(Ds, Name),
    Idx = [{col_index(C, Cols, Name), value(V, Params)} || {C, V} <- Sets],
    {New, N} = lists:foldr(fun(R, {Acc, K}) ->
                                   case holds(Where, R, Cols, Name, Params) of
                                       true -> {[set_cells(R, Idx) | Acc], K + 1};
                                       false -> {[R | Acc], K}
                                   end
                           end, {[], 0}, Rows),
    true = ets:insert(?DATA, {{Ds, Name}, Cols, New}),
    {ok, {count, N}};
apply_stmt(Ds, {delete, Name, Where}, Params) ->
    {Cols, Rows} = table(Ds, Name),
    Keep = [R || R <- Rows, not holds(Where, R, Cols, Name, Params)],
    true = ets:insert(?DATA, {{Ds, Name}, Cols, Keep}),
    {ok, {count, length(Rows) - length(Keep)}}.

set_cells(R, Idx) ->
    [case lists:keyfind(I, 1, Idx) of {_, V} -> V; false -> Old end
     || {I, Old} <- lists:zip(lists:seq(1, length(R)), R)].

holds(true, _R, _Cols, _T, _P) -> true;
holds({'and', A, B}, R, Cols, T, P) -> holds(A, R, Cols, T, P) andalso holds(B, R, Cols, T, P);
holds({'or', A, B}, R, Cols, T, P) -> holds(A, R, Cols, T, P) orelse holds(B, R, Cols, T, P);
holds({eq, A, B}, R, Cols, T, P) -> same(eval(A, R, Cols, T, P), eval(B, R, Cols, T, P));
holds({ne, A, B}, R, Cols, T, P) ->
    X = eval(A, R, Cols, T, P),
    Y = eval(B, R, Cols, T, P),
    X =/= null andalso Y =/= null andalso not same(X, Y).

%% SQL's NULL: equal to nothing, not even NULL.
same(null, _) -> false;
same(_, null) -> false;
same(X, Y) -> X =:= Y.

eval({col, C}, R, Cols, T, _P) -> lists:nth(col_index(C, Cols, T), R);
eval(V, _R, _Cols, _T, P) -> value(V, P).

sort_rows([], Rows, _Cols, _T) -> Rows;
sort_rows(Keys, Rows, Cols, T) ->
    Idx = [{col_index(C, Cols, T), D} || {C, D} <- Keys],
    lists:sort(fun(A, B) -> le(Idx, A, B) end, Rows).

le([], _A, _B) -> true;
le([{I, D} | Rest], A, B) ->
    X = key(lists:nth(I, A)),
    Y = key(lists:nth(I, B)),
    case X =:= Y of
        true -> le(Rest, A, B);
        false when D =:= asc -> X < Y;
        false -> X > Y
    end.

%% Numbers compare as numbers, everything else as text; NULL sorts first.
key(null) -> {0, 0};
key(V) ->
    try {1, binary_to_integer(V)} catch _:_ -> {2, V} end.
