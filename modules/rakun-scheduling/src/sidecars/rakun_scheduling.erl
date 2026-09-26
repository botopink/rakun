%%% rakun-scheduling — the task registry and the executor, BEAM half. Front 16.
%%%
%%% WHAT LIVES HERE AND WHY. A task is a FUNCTION and no string store holds one,
%%% and a timer is a process: both are host facts. So this module holds the task
%%% table, the supervision tree, the timer loop, the per-run worker, the calendar
%%% walk that finds a cron expression's next instant, and the test clock.
%%%
%%% WHAT DOES *NOT* LIVE HERE. Parsing a cron expression, every refusal message,
%%% the duplicate-name rule, reading configuration and rendering the endpoint are
%%% botopink (`cron.bp`, `registry.bp`, `executor.bp`, `endpoint.bp`). The walk
%%% below receives an expression already compiled to its six value lists (the
%%% "wire", `s|m|h|dom|mon|dow`, each a comma list) and never sees source text.
%%%
%%% THE SHAPE. One server process (`rakun_scheduling_server`) owns the ETS
%%% tables and serialises every mutation, so the overlap check and the counters
%%% are one atomic step. It is linked to the supervision tree:
%%%
%%%   rakun_scheduling_sup   one_for_one
%%%   ├── rakun_scheduling_timers   one_for_one — one timer process per started
%%%   │                             task, `permanent`: a dead timer is restarted
%%%   │                             and resumes from the next fire kept in ETS
%%%   └── rakun_scheduling_runs     simple_one_for_one — one `temporary` worker per
%%%                                 execution, started fresh for each run
%%%
%%% There is no pool and no queue: a run is a process started when it is due.
%%% Two tasks due at one instant are two workers; a task that raises takes down
%%% only its own worker (the raise is caught there and recorded as a failure).
%%%
%%% THE CLOCK. `now/0` is the wall clock, unless a test set a virtual instant with
%%% `clock_set/1`. Under a virtual clock a timer never wakes on its own; it fires
%%% only when `tick/1` asks it to, so no test waits on wall-clock time.
%%%
%%% MISSED FIRES. When a timer finds its next instant in the past (the node was
%%% busy, the timer was down, a test jumped the clock), it fires ONCE for the
%%% latest due instant if that instant is within `?GRACE` ms of now, and counts
%%% every earlier one as `missed` — never runs late, never catches up. Catch-up is
%%% front 84's.
-module(rakun_scheduling).
-behaviour(supervisor).

-export([init/1, start_timer/1, start_run/3]).
%% the registry
-export([register/7, owner_of/1, names/0, count/0, info/1, exists/1, forget/1,
         reset_stats/1]).
%% configuration and lifecycle
-export([configure/5, start/3, stop/0, started/0, global_enabled/0]).
%% execution
-export([run_now/1, run_async/1, tick/1, await_idle/1, in_flight/1, in_flight_total/0,
         run_pid/0]).
%% timers
-export([timer_alive/1, timer_pid/1, kill_timer/1]).
%% the clock and the calendar
-export([clock_set/1, clock_clear/0, now/0, next_cron/3, format_utc/1, to_i64/1]).
%% gates: what a test holds a run on instead of sleeping
-export([gate_wait/2, gate_open/1, gate_reset/1]).
%% reachable for a test
-export([ensure/0, server/1, mount_once/1]).

-define(SERVER, rakun_scheduling_server).
-define(SUP, rakun_scheduling_sup).
-define(TIMERS, rakun_scheduling_timers).
-define(RUNS, rakun_scheduling_runs).
-define(TASKS, rakun_scheduling_tasks).  %% set: {Name, Map}
-define(META, rakun_scheduling_meta).    %% set: {Key, Value}
-define(GRACE, 1000).
-define(EPOCH_GS, 62167219200).          %% gregorian seconds at 1970-01-01T00:00:00
-define(HORIZON_YEARS, 30).

%% ═══ lifecycle of the host ═══════════════════════════════════════════════════

ensure() ->
    case whereis(?SERVER) of
        undefined -> boot();
        _ -> ok
    end.

boot() ->
    Caller = self(),
    Pid = spawn(fun() -> server(Caller) end),
    Ref = erlang:monitor(process, Pid),
    receive
        {?SERVER, ready} -> erlang:demonitor(Ref, [flush]), ok;
        {'DOWN', Ref, process, Pid, _} -> ok
    after 5000 ->
        erlang:demonitor(Ref, [flush]), ok
    end.

server(Caller) ->
    case catch erlang:register(?SERVER, self()) of
        true ->
            process_flag(trap_exit, true),
            Common = [named_table, protected, {read_concurrency, true}],
            _ = ets:new(?TASKS, [set | Common]),
            _ = ets:new(?META, [set | Common]),
            true = ets:insert(?META, [{started, false}, {enabled, true}, {offset, 0},
                                      {clock, undefined}]),
            {ok, _Sup} = start_tree(),
            Caller ! {?SERVER, ready},
            loop(#{gates => #{}});
        _ ->
            Caller ! {?SERVER, ready},
            ok
    end.

start_tree() ->
    supervisor:start_link({local, ?SUP}, ?MODULE, top).

%% ═══ the supervision tree ════════════════════════════════════════════════════

init(top) ->
    Timers = #{id => timers, start => {supervisor, start_link, [{local, ?TIMERS}, ?MODULE, timers]},
               restart => permanent, shutdown => infinity, type => supervisor},
    Runs = #{id => runs, start => {supervisor, start_link, [{local, ?RUNS}, ?MODULE, runs]},
             restart => permanent, shutdown => infinity, type => supervisor},
    {ok, {#{strategy => one_for_one, intensity => 10, period => 60}, [Timers, Runs]}};
init(timers) ->
    {ok, {#{strategy => one_for_one, intensity => 100, period => 60}, []}};
init(runs) ->
    Worker = #{id => run, start => {?MODULE, start_run, []}, restart => temporary,
               shutdown => brutal_kill, type => worker},
    {ok, {#{strategy => simple_one_for_one, intensity => 100, period => 1}, [Worker]}}.

timer_spec(Name) ->
    #{id => Name, start => {?MODULE, start_timer, [Name]}, restart => permanent,
      shutdown => 1000, type => worker}.

%% ═══ the server ══════════════════════════════════════════════════════════════

call(Req) ->
    ensure(),
    Pid = whereis(?SERVER),
    Ref = erlang:monitor(process, Pid),
    Pid ! {call, self(), Ref, Req},
    receive
        {Ref, Reply} -> erlang:demonitor(Ref, [flush]), Reply;
        {'DOWN', Ref, process, Pid, Reason} -> erlang:error({rakun_scheduling_down, Reason})
    after 10000 ->
        erlang:demonitor(Ref, [flush]),
        erlang:error(rakun_scheduling_timeout)
    end.

loop(State) ->
    receive
        {call, From, Ref, Req} ->
            {Reply, Next} = handle(Req, State),
            From ! {Ref, Reply},
            loop(Next);
        {finished, Name, Kind, Outcome, At} ->
            finished(Name, Kind, Outcome, At),
            loop(State);
        {timer_up, Name, Pid} ->
            update(Name, fun(T) -> T#{timer => Pid} end),
            loop(State);
        {'EXIT', _From, _Reason} ->
            case whereis(?SUP) of
                undefined -> restart_tree();
                _ -> ok
            end,
            loop(State);
        _ ->
            loop(State)
    end.

%% The tree died (its restart intensity ran out). Rebuild it and restart the
%% timers of a started scheduler: the next fires are in ETS, so nothing is lost.
restart_tree() ->
    case start_tree() of
        {ok, _} ->
            case meta(started) andalso meta(enabled) of
                true -> [start_child(N) || {N, T} <- ets:tab2list(?TASKS), maps:get(enabled, T)];
                false -> ok
            end;
        _ -> ok
    end.

handle({register, Name, Owner, Trigger, Expr, Wire, Interval, Fun}, S) ->
    Row = case ets:lookup(?TASKS, Name) of
              [{_, Old}] -> Old#{owner => Owner, trigger => Trigger, expr => Expr, wire => Wire,
                                 declared_expr => Expr, declared_wire => Wire,
                                 interval => Interval, fn => Fun};
              [] -> fresh(Name, Owner, Trigger, Expr, Wire, Interval, Fun)
          end,
    true = ets:insert(?TASKS, {Name, Row}),
    {0, S};
handle({forget, Name}, S) ->
    stop_child(Name),
    true = ets:delete(?TASKS, Name),
    {0, S};
handle({reset_stats, Name}, S) ->
    update(Name, fun(T) -> T#{last_started => 0, last_finished => 0, last_result => 0,
                              runs => 0, failures => 0, missed => 0, last_error => <<>>} end),
    {0, S};
handle({configure, Name, Enabled, Overlap, Expr, Wire}, S) ->
    update(Name, fun(T) ->
                         T1 = T#{enabled => Enabled, overlap => Overlap},
                         case Expr of
                             <<>> -> T1#{expr => maps:get(declared_expr, T),
                                         wire => maps:get(declared_wire, T)};
                             _ -> T1#{expr => Expr, wire => Wire}
                         end
                 end),
    {0, S};
handle({start, Names, Enabled, Offset}, S) ->
    true = ets:insert(?META, [{started, true}, {enabled, Enabled}, {offset, Offset}]),
    Now = now(),
    Started = case Enabled of
                  false -> 0;
                  true ->
                      lists:foldl(
                        fun(Name, Acc) ->
                                case ets:lookup(?TASKS, Name) of
                                    [{_, #{enabled := true} = T}] ->
                                        true = ets:insert(?TASKS, {Name, T#{next => first_fire(T, Now)}}),
                                        start_child(Name),
                                        Acc + 1;
                                    _ -> Acc
                                end
                        end, 0, Names)
              end,
    {Started, S};
handle(stop, S) ->
    [stop_child(N) || {N, _} <- ets:tab2list(?TASKS)],
    true = ets:insert(?META, {started, false}),
    [update(N, fun(T) -> T#{next => 0, timer => undefined} end) || {N, _} <- ets:tab2list(?TASKS)],
    {0, S};
handle({due, Name}, S) ->
    {due(Name, now()), S};
handle({manual, Name}, S) ->
    Reply = case ets:lookup(?TASKS, Name) of
                [] -> unknown;
                [{_, T}] -> admit(Name, T, now())
            end,
    {Reply, S};
handle({clock, Value}, S) ->
    true = ets:insert(?META, {clock, Value}),
    {0, S};
handle({gate_wait, Key, Pid}, #{gates := G} = S) ->
    case maps:get(Key, G, []) of
        open -> {open, S};
        Waiters -> {wait, S#{gates => G#{Key => [Pid | Waiters]}}}
    end;
handle({gate_open, Key}, #{gates := G} = S) ->
    case maps:get(Key, G, []) of
        open -> ok;
        Waiters -> [W ! {rakun_scheduling_gate, Key} || W <- Waiters]
    end,
    {0, S#{gates => G#{Key => open}}};
handle({gate_reset, Key}, #{gates := G} = S) ->
    {0, S#{gates => maps:remove(Key, G)}};
handle({mount_once, Key}, S) ->
    {ets:insert_new(?META, {{mount, Key}, true}), S};
handle(_Other, S) ->
    {error, S}.

fresh(Name, Owner, Trigger, Expr, Wire, Interval, Fun) ->
    #{name => Name, owner => Owner, trigger => Trigger, expr => Expr, wire => Wire,
      declared_expr => Expr, declared_wire => Wire, interval => Interval, fn => Fun, enabled => true, overlap => <<"skip">>,
      last_started => 0, last_finished => 0, last_result => 0, last_error => <<>>,
      next => 0, runs => 0, failures => 0, missed => 0, in_flight => 0,
      timer => undefined}.

update(Name, F) ->
    case ets:lookup(?TASKS, Name) of
        [{_, T}] -> true = ets:insert(?TASKS, {Name, F(T)});
        [] -> ok
    end.

meta(Key) ->
    case ets:lookup(?META, Key) of
        [{_, V}] -> V;
        [] -> undefined
    end.

start_child(Name) ->
    _ = supervisor:terminate_child(?TIMERS, Name),
    _ = supervisor:delete_child(?TIMERS, Name),
    case supervisor:start_child(?TIMERS, timer_spec(Name)) of
        {ok, Pid} -> update(Name, fun(T) -> T#{timer => Pid} end);
        _ -> ok
    end,
    ok.

stop_child(Name) ->
    _ = supervisor:terminate_child(?TIMERS, Name),
    _ = supervisor:delete_child(?TIMERS, Name),
    ok.

%% ═══ triggers ════════════════════════════════════════════════════════════════

first_fire(#{trigger := <<"cron">>, wire := Wire}, Now) ->
    next_cron(Wire, Now, meta(offset));
first_fire(#{interval := I}, Now) ->
    Now + I.

%% The instant after `At` in a task's series (cron, or the rate/delay step).
step(#{trigger := <<"cron">>, wire := Wire}, At) ->
    next_cron(Wire, At, meta(offset));
step(#{interval := I}, At) ->
    At + I.

%% Is the task due at `Now`? Advances its next fire, counts what it missed, and
%% admits a run (subject to the overlap rule) when the latest due instant is
%% within the grace window.
due(Name, Now) ->
    case ets:lookup(?TASKS, Name) of
        [{_, #{next := Next} = T}] when Next > 0, Next =< Now ->
            {Latest, Skipped} = latest(T, Next, Now, 0),
            Late = Now - Latest > ?GRACE,
            Missed0 = maps:get(missed, T) + Skipped + (case Late of true -> 1; false -> 0 end),
            Following = step(T, Latest),
            T1 = T#{missed => Missed0, next => Following},
            case Late of
                true ->
                    true = ets:insert(?TASKS, {Name, T1}),
                    none;
                false ->
                    case admit(Name, T1, Now) of
                        {fire, Fun} ->
                            case maps:get(trigger, T1) of
                                <<"fixedDelay">> -> update(Name, fun(X) -> X#{next => 0} end);
                                _ -> ok
                            end,
                            {fire, Fun};
                        Other -> Other
                    end
            end;
        _ -> none
    end.

%% The latest instant of the series that is =< Now, and how many earlier ones
%% were passed over.
latest(#{trigger := <<"cron">>} = T, At, Now, N) when N < 1000000 ->
    Following = step(T, At),
    case Following > 0 andalso Following =< Now of
        true -> latest(T, Following, Now, N + 1);
        false -> {At, N}
    end;
latest(#{trigger := <<"cron">>}, At, _Now, N) ->
    {At, N};
latest(#{interval := I}, At, Now, _N) ->
    K = (Now - At) div I,
    {At + K * I, K}.

%% One run, if the overlap rule lets it start. Writes the row either way.
admit(Name, T, Now) ->
    Busy = maps:get(in_flight, T) > 0,
    case Busy andalso maps:get(overlap, T) =:= <<"skip">> of
        true ->
            true = ets:insert(?TASKS, {Name, T#{missed => maps:get(missed, T) + 1}}),
            skipped;
        false ->
            true = ets:insert(?TASKS, {Name, T#{in_flight => maps:get(in_flight, T) + 1,
                                                last_started => Now}}),
            {fire, maps:get(fn, T)}
    end.

finished(Name, Kind, Outcome, At) ->
    update(Name, fun(T) ->
                         T1 = T#{in_flight => max(0, maps:get(in_flight, T) - 1),
                                 last_finished => At, runs => maps:get(runs, T) + 1},
                         T2 = case Outcome of
                                  {ok, R} when is_integer(R) -> T1#{last_result => R, last_error => <<>>};
                                  {ok, _} -> T1#{last_result => 0, last_error => <<>>};
                                  {error, Why} -> T1#{failures => maps:get(failures, T) + 1,
                                                      last_error => Why}
                              end,
                         Delay = maps:get(trigger, T) =:= <<"fixedDelay">>,
                         case Kind =:= scheduled andalso Delay andalso meta(started) of
                             true -> T2#{next => At + maps:get(interval, T)};
                             false -> T2
                         end
                 end),
    case ets:lookup(?TASKS, Name) of
        [{_, #{timer := P}}] when is_pid(P) -> P ! rearm;
        _ -> ok
    end,
    ok.

%% ═══ the timer ═══════════════════════════════════════════════════════════════

start_timer(Name) ->
    Pid = proc_lib:spawn_link(fun() -> timer_init(Name) end),
    {ok, Pid}.

timer_init(Name) ->
    whereis(?SERVER) ! {timer_up, Name, self()},
    timer_loop(Name).

timer_loop(Name) ->
    Wait = case meta(clock) of
               undefined ->
                   case ets:lookup(?TASKS, Name) of
                       [{_, #{next := N}}] when N > 0 -> min(60000, max(0, N - now()));
                       _ -> infinity
                   end;
               _ -> infinity
           end,
    receive
        {tick, From, Ref} ->
            Fired = fire_due(Name),
            From ! {Ref, Fired},
            timer_loop(Name);
        rearm ->
            timer_loop(Name);
        stop ->
            ok
    after Wait ->
        _ = fire_due(Name),
        timer_loop(Name)
    end.

fire_due(Name) ->
    case call({due, Name}) of
        {fire, Fun} -> spawn_run(Name, Fun, scheduled), 1;
        _ -> 0
    end.

%% ═══ the run worker ══════════════════════════════════════════════════════════

spawn_run(Name, Fun, Kind) ->
    case supervisor:start_child(?RUNS, [Name, Fun, Kind]) of
        {ok, Pid} -> Pid;
        _ -> undefined
    end.

start_run(Name, Fun, Kind) ->
    {ok, proc_lib:spawn_link(fun() -> run(Name, Fun, Kind) end)}.

run(Name, Fun, Kind) ->
    put(rakun_scheduling_task, Name),
    Outcome = try {ok, Fun()}
              catch
                  Class:Reason -> {error, reason_text(Class, Reason)}
              end,
    whereis(?SERVER) ! {finished, Name, Kind, Outcome, now()},
    ok.

reason_text(_Class, Reason) when is_binary(Reason) -> Reason;
reason_text(_Class, {panic, Msg}) when is_binary(Msg) -> Msg;
reason_text(Class, Reason) ->
    iolist_to_binary(io_lib:format("~p:~0p", [Class, Reason])).

%% ═══ the registry cells ══════════════════════════════════════════════════════

register(Name, Owner, Trigger, Expr, Wire, Interval, Fun) ->
    call({register, Name, Owner, Trigger, Expr, Wire, Interval, Fun}).

owner_of(Name) ->
    ensure(),
    case ets:lookup(?TASKS, Name) of
        [{_, #{owner := O}}] -> O;
        [] -> <<>>
    end.

exists(Name) ->
    ensure(),
    ets:member(?TASKS, Name).

names() ->
    ensure(),
    join(lists:sort([N || {N, _} <- ets:tab2list(?TASKS)]), <<"\n">>).

count() ->
    ensure(),
    ets:info(?TASKS, size).

forget(Name) -> call({forget, Name}).

reset_stats(Name) -> call({reset_stats, Name}).

%% The `TaskInfo` record, as the map botopink reads a record as.
info(Name) ->
    ensure(),
    case ets:lookup(?TASKS, Name) of
        [{_, T}] ->
            #{name => Name, owner => maps:get(owner, T), trigger => maps:get(trigger, T),
              expression => maps:get(expr, T), lastStartedAt => maps:get(last_started, T),
              lastFinishedAt => maps:get(last_finished, T), lastResult => maps:get(last_result, T),
              nextFireAt => maps:get(next, T), runs => maps:get(runs, T),
              failures => maps:get(failures, T), missed => maps:get(missed, T),
              enabled => maps:get(enabled, T), overlap => maps:get(overlap, T),
              inFlight => maps:get(in_flight, T), lastError => maps:get(last_error, T)};
        [] ->
            #{name => <<>>, owner => <<>>, trigger => <<>>, expression => <<>>,
              lastStartedAt => 0, lastFinishedAt => 0, lastResult => 0, nextFireAt => 0,
              runs => 0, failures => 0, missed => 0, enabled => false, overlap => <<>>,
              inFlight => 0, lastError => <<>>}
    end.

%% ═══ configuration and lifecycle cells ═══════════════════════════════════════

configure(Name, Enabled, Overlap, Expr, Wire) ->
    call({configure, Name, Enabled, Overlap, Expr, Wire}).

%% `Names` is a newline-joined list; answers how many timers were started.
start(Names, Enabled, Offset) ->
    List = [N || N <- binary:split(Names, <<"\n">>, [global]), N =/= <<>>],
    call({start, List, Enabled, Offset}).

stop() -> call(stop).

started() ->
    ensure(),
    meta(started) =:= true.

global_enabled() ->
    ensure(),
    meta(enabled) =:= true.

%% ═══ execution cells ═════════════════════════════════════════════════════════

%% Runs a task once, out of band, in a worker of its own, and waits for it:
%% 1 when it ran (and was recorded), 0 when the overlap rule skipped it, -1 when
%% no task has that name.
run_now(Name) ->
    case call({manual, Name}) of
        unknown -> -1;
        skipped -> 0;
        {fire, Fun} ->
            case spawn_run(Name, Fun, manual) of
                undefined -> 0;
                Pid ->
                    Ref = erlang:monitor(process, Pid),
                    receive {'DOWN', Ref, process, Pid, _} -> ok end,
                    await_recorded(Name, 1000),
                    1
            end
    end.

%% The same, without waiting: what `POST …/run` answers 202 for.
run_async(Name) ->
    case call({manual, Name}) of
        unknown -> -1;
        skipped -> 0;
        {fire, Fun} ->
            _ = spawn_run(Name, Fun, manual),
            1
    end.

%% The worker's `finished` message reaches the server after the worker exits; a
%% synchronous round trip through the server orders the read after it.
await_recorded(_Name, _Ms) ->
    _ = call({clock, meta(clock)}),
    ok.

%% Every started timer checks whether it is due at the (virtual) instant `At`.
%% Answers how many runs were started.
tick(At) ->
    _ = call({clock, At}),
    Timers = [P || {_, #{timer := P}} <- ets:tab2list(?TASKS), is_pid(P), is_process_alive(P)],
    Refs = [begin R = make_ref(), P ! {tick, self(), R}, R end || P <- Timers],
    lists:sum([receive {R, Fired} -> Fired after 5000 -> 0 end || R <- Refs]).

%% Waits until no run is in flight, up to `Ms`; answers how many still are.
await_idle(Ms) ->
    Deadline = erlang:monotonic_time(millisecond) + Ms,
    await_idle_until(Deadline).

await_idle_until(Deadline) ->
    _ = call({clock, meta(clock)}),
    case in_flight_total() of
        0 -> 0;
        N ->
            case erlang:monotonic_time(millisecond) >= Deadline of
                true -> N;
                false -> receive after 1 -> await_idle_until(Deadline) end
            end
    end.

in_flight(Name) ->
    ensure(),
    case ets:lookup(?TASKS, Name) of
        [{_, #{in_flight := N}}] -> N;
        [] -> 0
    end.

in_flight_total() ->
    ensure(),
    lists:sum([maps:get(in_flight, T) || {_, T} <- ets:tab2list(?TASKS)]).

%% The current process as text: which worker a task body runs in.
run_pid() ->
    list_to_binary(pid_to_list(self())).

%% ═══ timer cells ═════════════════════════════════════════════════════════════

timer_pid(Name) ->
    ensure(),
    case ets:lookup(?TASKS, Name) of
        [{_, #{timer := P}}] when is_pid(P) -> P;
        _ -> undefined
    end.

timer_alive(Name) ->
    case timer_pid(Name) of
        undefined -> false;
        P -> is_process_alive(P)
    end.

%% Kills a task's timer and waits (up to two seconds) for its supervisor to
%% start a new one. Answers 1 when a different, live timer took its place.
kill_timer(Name) ->
    case timer_pid(Name) of
        undefined -> 0;
        Old ->
            Ref = erlang:monitor(process, Old),
            exit(Old, kill),
            receive {'DOWN', Ref, process, Old, _} -> ok after 2000 -> ok end,
            await_new_timer(Name, Old, erlang:monotonic_time(millisecond) + 2000)
    end.

await_new_timer(Name, Old, Deadline) ->
    _ = call({clock, meta(clock)}),
    case timer_pid(Name) of
        P when is_pid(P), P =/= Old ->
            case is_process_alive(P) of true -> 1; false -> 0 end;
        _ ->
            case erlang:monotonic_time(millisecond) >= Deadline of
                true -> 0;
                false -> receive after 1 -> await_new_timer(Name, Old, Deadline) end
            end
    end.

%% ═══ the clock ═══════════════════════════════════════════════════════════════

clock_set(At) -> call({clock, At}).

clock_clear() -> call({clock, undefined}).

now() ->
    case ets:whereis(?META) of
        undefined -> erlang:system_time(millisecond);
        _ ->
            case meta(clock) of
                undefined -> erlang:system_time(millisecond);
                At -> At
            end
    end.

to_i64(N) -> N.

format_utc(Millis) ->
    list_to_binary(calendar:system_time_to_rfc3339(Millis div 1000,
                                                   [{unit, second}, {offset, "Z"}])).

%% ═══ the calendar walk ═══════════════════════════════════════════════════════
%%
%% The first instant strictly after `After` (epoch millis) whose local civil
%% time, at `Offset` minutes east of UTC, matches every field. -1 when none does
%% within ?HORIZON_YEARS (an expression such as `0 0 0 30 2 ?`). Day-of-month
%% and day-of-week must BOTH match; `?` and `*` both mean every value, so the
%% usual `* … 1-5` and `… 1 * ?` forms read as expected.

next_cron(Wire, After, Offset) ->
    Sets = parse_wire(Wire),
    Start = After div 1000 + 1,
    Local = Start + Offset * 60 + ?EPOCH_GS,
    {{Y, _, _}, _} = calendar:gregorian_seconds_to_datetime(Local),
    case search(Local, Sets, Y + ?HORIZON_YEARS) of
        none -> -1;
        Found -> (Found - ?EPOCH_GS - Offset * 60) * 1000
    end.

parse_wire(Wire) ->
    [S, Mi, H, Dom, Mo, Dow] = binary:split(Wire, <<"|">>, [global]),
    [ints(S), ints(Mi), ints(H), ints(Dom), ints(Mo), ints(Dow)].

ints(Bin) ->
    [binary_to_integer(X) || X <- binary:split(Bin, <<",">>, [global]), X =/= <<>>].

search(Gs, [Ss, Mis, Hs, Doms, Mos, Dows] = Sets, Limit) ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:gregorian_seconds_to_datetime(Gs),
    if
        Y > Limit -> none;
        true ->
            case lists:member(Mo, Mos) of
                false -> search(month_start(Y, Mo + 1), Sets, Limit);
                true ->
                    Dow = calendar:day_of_the_week(Y, Mo, D) rem 7,
                    case lists:member(D, Doms) andalso lists:member(Dow, Dows) of
                        false -> search(day_start(Y, Mo, D) + 86400, Sets, Limit);
                        true ->
                            case lists:member(H, Hs) of
                                false -> search(day_start(Y, Mo, D) + (H + 1) * 3600, Sets, Limit);
                                true ->
                                    case lists:member(Mi, Mis) of
                                        false -> search(day_start(Y, Mo, D) + H * 3600 + (Mi + 1) * 60, Sets, Limit);
                                        true ->
                                            case lists:member(S, Ss) of
                                                false -> search(Gs + 1, Sets, Limit);
                                                true -> Gs
                                            end
                                    end
                            end
                    end
            end
    end.

month_start(Y, 13) -> month_start(Y + 1, 1);
month_start(Y, Mo) -> calendar:datetime_to_gregorian_seconds({{Y, Mo, 1}, {0, 0, 0}}).

day_start(Y, Mo, D) -> calendar:datetime_to_gregorian_seconds({{Y, Mo, D}, {0, 0, 0}}).

%% ═══ gates ═══════════════════════════════════════════════════════════════════
%%
%% A gate is a named latch: `gate_wait` blocks the caller until `gate_open` is
%% called for the key (or the timeout passes, answering false). It is how a test
%% keeps a run in flight, or proves two runs overlap, without sleeping.

gate_wait(Key, Ms) ->
    case call({gate_wait, Key, self()}) of
        open -> true;
        wait ->
            receive {rakun_scheduling_gate, Key} -> true
            after Ms -> false
            end
    end.

gate_open(Key) -> call({gate_open, Key}).

gate_reset(Key) -> call({gate_reset, Key}).

%% True the first time a key is claimed: what keeps a route registered once.
mount_once(Key) -> call({mount_once, Key}).

%% ═══ helpers ═════════════════════════════════════════════════════════════════

join([], _Sep) -> <<>>;
join(List, Sep) -> iolist_to_binary(lists:join(Sep, List)).
