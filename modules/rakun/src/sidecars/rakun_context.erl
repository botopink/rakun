%%% rakun — the container's doors, BEAM half: the erlang twin of
%%% `src/context.mjs`.
%%%
%%% WHAT LIVES HERE AND WHY. botopink has no top-level mutable state, so a
%%% registry lives in the host. What this one stores is a bean FACTORY, a
%%% lifecycle THUNK, a listener CLOSURE and an exit-code GENERATOR — four
%%% funs. No string property table holds a fun, which is the measurement fronts
%%% 22 and 62 each made and front 05 made the other way.
%%%
%%% WHAT DOES NOT LIVE HERE. The bean record's grammar, the choice between two
%%% candidates, every refusal message, the boot-event order and the reverse of
%%% the pre-destroy pass are botopink (`context.bp`, `lifecycle.bp`,
%%% `events.bp`), compiled to both targets. This module is handed a finished
%%% `path|type|qualifier|scope|primary|lazy` line and appends it beside its
%%% fun; it never parses one, never compares a qualifier and never decides
%%% which of two beans wins. Neither host knows the format, which is what makes
%%% "the two rows cannot disagree about what the container holds" a property
%%% rather than a hope.
%%%
%%% MODULE ATOM. `src/sidecars/rakun_context.erl`, never `src/context.erl`:
%%% `shipErlSidecars` skips any qualifier atom matching a module the build
%%% emitted, rakun emits `rakun/context`, and the skip is SILENT — the build
%%% exits 0 and the program dies with `undefined function context:bean_table/0`.
%%% Every rakun sidecar is `rakun_<name>.erl`.
%%%
%%% TABLE OWNERSHIP. An ETS table dies with the process that created it, and a
%%% registration runs in whatever process loaded the module. So the tables are
%%% created by a dedicated owner process that does nothing but stay alive,
%%% registered under a name so a second caller losing the race finds them
%%% already there. Like `rakun_file_router`, this module deliberately does not
%%% reuse `rakun_runtime`'s supervision tree: the sidecars are shipped
%%% independently, per atom named in emitted output.
%%%
%%% THE REQUEST SCOPE IS THE PROCESS DICTIONARY. A request is a process on the
%%% BEAM, so "per request" and "per process" are the same statement and two
%%% concurrent requests get their own instance with no bookkeeping at all. The
%%% node twin has to bracket it instead, because node is single-threaded.
-module(rakun_context).

-export([bean_register/2, bean_table/0, bean_count/0, bean_has_record/1,
         bean_invoke/1, bean_touch/1, bean_reset/0,
         request_scoped/2, request_scope_end/0,
         lifecycle_register/2, lifecycle_table/0, lifecycle_run/2,
         lifecycle_reset/0,
         listener_register/2, listener_table/0, listener_emit/2,
         listener_failures/0, listener_reset/0,
         exit_register/2, exit_values/0, exit_reset/0,
         note/1, note_log/0, note_reset/0, bump/1, counted/1]).

%% reachable for a test or a later front
-export([ensure/0, owner/1]).

-define(BEANS, rakun_ctx_beans).      %% ordered_set: {Seq, Record, Factory}
-define(HOOKS, rakun_ctx_hooks).      %% ordered_set: {Seq, Record, Fun, Done}
-define(LISTEN, rakun_ctx_listeners). %% ordered_set: {Seq, Record, Fun}
-define(FAILED, rakun_ctx_failed).    %% ordered_set: {Seq, Record}
-define(EXITS, rakun_ctx_exits).      %% ordered_set: {Seq, Name, Fun}
-define(NOTES, rakun_ctx_notes).      %% ordered_set: {Seq, Line}
-define(COUNT, rakun_ctx_counters).   %% set:         {Key, Integer}
-define(SEQ, rakun_ctx_seq).          %% set:         {Name, Integer}
-define(OWNER, rakun_ctx_owner).

%% ═══ lifecycle of the tables ════════════════════════════════════════════════

ensure() ->
    case ets:whereis(?BEANS) of
        undefined -> boot();
        _ -> ok
    end.

boot() ->
    Caller = self(),
    Pid = spawn(fun() -> owner(Caller) end),
    Ref = erlang:monitor(process, Pid),
    receive
        {?OWNER, ready} ->
            erlang:demonitor(Ref, [flush]),
            ok;
        {'DOWN', Ref, process, Pid, _} ->
            ok
    after 5000 ->
        erlang:demonitor(Ref, [flush]),
        ok
    end.

%% The owner: create the tables, tell the caller they exist, then stay alive.
%% A second owner that loses `register/2` answers the caller anyway and exits,
%% so nothing waits on a race it lost.
owner(Caller) ->
    Won = try erlang:register(?OWNER, self()) catch _:_ -> false end,
    case Won of
        true ->
            Common = [named_table, public, {read_concurrency, true}],
            _ = ets:new(?BEANS, [ordered_set | Common]),
            _ = ets:new(?HOOKS, [ordered_set | Common]),
            _ = ets:new(?LISTEN, [ordered_set | Common]),
            _ = ets:new(?FAILED, [ordered_set | Common]),
            _ = ets:new(?EXITS, [ordered_set | Common]),
            _ = ets:new(?NOTES, [ordered_set | Common]),
            _ = ets:new(?COUNT, [set | Common]),
            _ = ets:new(?SEQ, [set | Common]),
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

next_seq(Name) ->
    ets:update_counter(?SEQ, Name, {2, 1}, {Name, 0}).

to_bin(B) when is_binary(B) -> B;
to_bin(L) when is_list(L) -> list_to_binary(L).

join([]) -> <<>>;
join([H | T]) ->
    lists:foldl(fun(X, Acc) -> <<Acc/binary, "\n", X/binary>> end,
                to_bin(H), [to_bin(X) || X <- T]).

%% The one place this module looks INSIDE a record, and it reads positions, not
%% meanings: field 3 of a hook line is its phase and field 4 its order, because
%% the pass has to group and sort. It still does not know what a phase means.
field(Record, N) ->
    case binary:split(to_bin(Record), <<"|">>, [global]) of
        Fields when length(Fields) >= N -> lists:nth(N, Fields);
        _ -> <<>>
    end.

int_of(Bin) ->
    case string:to_integer(binary_to_list(Bin)) of
        {error, _} -> 0;
        {N, _} -> N
    end.

%% ═══ beans ══════════════════════════════════════════════════════════════════

bean_register(Record, Factory) ->
    ensure(),
    Seq = next_seq(beans),
    true = ets:insert(?BEANS, {Seq, to_bin(Record), Factory}),
    ets:info(?BEANS, size).

bean_table() ->
    ensure(),
    join([R || {_S, R, _F} <- ets:tab2list(?BEANS)]).

bean_count() ->
    ensure(),
    ets:info(?BEANS, size).

bean_has_record(Record) ->
    ensure(),
    R = to_bin(Record),
    lists:any(fun({_S, Rec, _F}) -> Rec =:= R end, ets:tab2list(?BEANS)).

%% Invoke the factory stored under this EXACT record line. botopink picked the
%% line out of `bean_table/0`; this is an equality test and a call.
bean_invoke(Record) ->
    ensure(),
    R = to_bin(Record),
    case [F || {_S, Rec, F} <- ets:tab2list(?BEANS), Rec =:= R] of
        [F | _] -> F();
        [] -> undefined
    end.

%% The same call with the value discarded, for the eager pass: the caller has no
%% type to bind the result to, and a construction that raises must still raise.
bean_touch(Record) ->
    ensure(),
    R = to_bin(Record),
    case [F || {_S, Rec, F} <- ets:tab2list(?BEANS), Rec =:= R] of
        [F | _] -> _ = F(), 1;
        [] -> 0
    end.

bean_reset() ->
    ensure(),
    true = ets:delete_all_objects(?BEANS),
    true = ets:insert(?SEQ, {beans, 0}),
    0.

%% ═══ request scope ══════════════════════════════════════════════════════════
%%
%% A request is a process, so the cache is the process dictionary: two
%% concurrent requests never see each other's instance and nothing has to be
%% keyed by a request id.

request_scoped(Key, Build) ->
    K = {rakun_ctx_req, to_bin(Key)},
    case erlang:get(K) of
        undefined ->
            Value = Build(),
            erlang:put(K, {ok, Value}),
            Value;
        {ok, Value} ->
            Value
    end.

request_scope_end() ->
    Keys = [K || {{rakun_ctx_req, _} = K, _} <- erlang:get()],
    lists:foreach(fun(K) -> erlang:erase(K) end, Keys),
    length(Keys).

%% ═══ lifecycle ══════════════════════════════════════════════════════════════

lifecycle_register(Record, Run) ->
    ensure(),
    Seq = next_seq(hooks),
    true = ets:insert(?HOOKS, {Seq, to_bin(Record), Run, false}),
    ets:info(?HOOKS, size).

lifecycle_table() ->
    ensure(),
    join([R || {_S, R, _F, _D} <- ets:tab2list(?HOOKS)]).

%% Run every not-yet-run entry of Phase, by `order` then registration order —
%% REVERSED for `pre`, which is reverse dependency order because a component is
%% registered after the components it was constructed from. Answers the
%% `owner|method` of each entry that raised; Tolerant decides whether the pass
%% stops at the first one. The caller writes the message.
lifecycle_run(Phase, Tolerant) ->
    ensure(),
    P = to_bin(Phase),
    Picked0 = [{int_of(field(R, 4)), S, R, F}
               || {S, R, F, Done} <- ets:tab2list(?HOOKS),
                  Done =:= false, field(R, 3) =:= P],
    Picked1 = lists:sort(Picked0),
    Picked = case P of
                 <<"pre">> -> lists:reverse(Picked1);
                 _ -> Picked1
             end,
    Failed = run_hooks(Picked, Tolerant, []),
    join(lists:reverse(Failed)).

run_hooks([], _Tolerant, Acc) -> Acc;
run_hooks([{_O, Seq, Record, Fun} | Rest], Tolerant, Acc) ->
    [{Seq, R0, F0, _}] = ets:lookup(?HOOKS, Seq),
    true = ets:insert(?HOOKS, {Seq, R0, F0, true}),
    %% try/catch and not `catch`: a `@panic` lowers to one class on one row and
    %% a bare `catch` of a `throw` hands back the thrown value, which is
    %% indistinguishable from a hook that returned it.
    Ok = try Fun(), true catch _:_ -> false end,
    case Ok of
        false ->
            Who = <<(field(Record, 1))/binary, "|", (field(Record, 2))/binary>>,
            case Tolerant of
                true -> run_hooks(Rest, Tolerant, [Who | Acc]);
                _ -> [Who | Acc]
            end;
        true ->
            run_hooks(Rest, Tolerant, Acc)
    end.

lifecycle_reset() ->
    ensure(),
    true = ets:delete_all_objects(?HOOKS),
    true = ets:insert(?SEQ, {hooks, 0}),
    0.

%% ═══ listeners ══════════════════════════════════════════════════════════════

listener_register(Record, Run) ->
    ensure(),
    Seq = next_seq(listeners),
    true = ets:insert(?LISTEN, {Seq, to_bin(Record), Run}),
    ets:info(?LISTEN, size).

listener_table() ->
    ensure(),
    join([R || {_S, R, _F} <- ets:tab2list(?LISTEN)]).

%% Dispatch is synchronous and in registration order. A listener that raises is
%% recorded and the sequence continues, because a broken audit listener must not
%% take the boot down. Answers how many listeners ran.
listener_emit(EventName, Event) ->
    ensure(),
    N = to_bin(EventName),
    Picked = [{S, R, F} || {S, R, F} <- ets:tab2list(?LISTEN),
                           field(R, 1) =:= N],
    lists:foldl(fun({_S, R, F}, Acc) ->
                        Ok = try F(Event), true catch _:_ -> false end,
                        case Ok of
                            false ->
                                Seq = next_seq(failed),
                                true = ets:insert(?FAILED, {Seq, R}),
                                Acc + 1;
                            true ->
                                Acc + 1
                        end
                end, 0, Picked).

listener_failures() ->
    ensure(),
    join([R || {_S, R} <- ets:tab2list(?FAILED)]).

listener_reset() ->
    ensure(),
    true = ets:delete_all_objects(?LISTEN),
    true = ets:delete_all_objects(?FAILED),
    true = ets:insert(?SEQ, {listeners, 0}),
    true = ets:insert(?SEQ, {failed, 0}),
    0.

%% ═══ exit codes ═════════════════════════════════════════════════════════════

exit_register(Name, Gen) ->
    ensure(),
    Seq = next_seq(exits),
    true = ets:insert(?EXITS, {Seq, to_bin(Name), Gen}),
    ets:info(?EXITS, size).

%% Every generator called, its answer in registration order. The caller takes
%% the maximum — arithmetic is botopink's.
exit_values() ->
    ensure(),
    join([integer_to_binary(G()) || {_S, _N, G} <- ets:tab2list(?EXITS)]).

exit_reset() ->
    ensure(),
    true = ets:delete_all_objects(?EXITS),
    true = ets:insert(?SEQ, {exits, 0}),
    0.

%% ═══ the test seam: an ordered note log and a counter table ═════════════════
%%
%% The boot sequence is asserted by registering a listener for every one of the
%% eight events that appends its name here, then comparing the log to the
%% documented order — which catches a reordering a per-event test would not.

note(Line) ->
    ensure(),
    Seq = next_seq(notes),
    true = ets:insert(?NOTES, {Seq, to_bin(Line)}),
    ets:info(?NOTES, size).

note_log() ->
    ensure(),
    join([L || {_S, L} <- ets:tab2list(?NOTES)]).

note_reset() ->
    ensure(),
    true = ets:delete_all_objects(?NOTES),
    true = ets:delete_all_objects(?COUNT),
    true = ets:insert(?SEQ, {notes, 0}),
    0.

bump(Key) ->
    ensure(),
    ets:update_counter(?COUNT, to_bin(Key), {2, 1}, {to_bin(Key), 0}).

counted(Key) ->
    ensure(),
    case ets:lookup(?COUNT, to_bin(Key)) of
        [{_, N}] -> N;
        [] -> 0
    end.
