%%% rakun — the auto-configuration registry, BEAM half: the erlang twin of
%%% `src/autoconfig.mjs`.
%%%
%%% WHAT LIVES HERE AND WHY. botopink has no top-level mutable state, so a
%%% registry lives in the host. What this one stores is four STRINGS per
%%% registration — the name, the condition blob, the `before` list and the
%%% `after` list — plus one decision per name once the apply pass has run.
%%%
%%% WHAT DOES NOT LIVE HERE. The condition blob's grammar, the topological
%%% sort, the evaluation of every record, the refusal texts and the rendered
%%% report are botopink (`conditions.bp`, `autoconfig.bp`,
%%% `condition_report.bp`), compiled to both targets. Front 06's measurement is
%%% what decides the split: it stores four kinds of FUN and no string table
%%% holds a fun, so its grammar stayed in botopink and its table went to the
%%% host. Here nothing is a fun, so only the table crosses. This module appends
%%% a row and answers a lookup; it never splits a blob on `;`, never compares a
%%% property and never decides whether anything matched.
%%%
%%% MODULE ATOM. `src/sidecars/rakun_autoconfig.erl`, never `src/autoconfig.erl`:
%%% `shipErlSidecars` skips any qualifier atom matching a module the build
%%% emitted, rakun emits `rakun/autoconfig`, and the skip is SILENT — the build
%%% exits 0 and the program dies with `undefined function autoconfig:auto_names/0`.
%%% Every rakun sidecar is `rakun_<name>.erl`.
%%%
%%% TABLE OWNERSHIP. An ETS table dies with the process that created it, and a
%%% registration runs in whatever process loaded the module. So the tables are
%%% created by a dedicated owner process that does nothing but stay alive,
%%% registered under a name so a second caller losing the race finds them
%%% already there — the same shape `rakun_context` and `rakun_file_router` use,
%%% and for the same reason each of them declines to reuse `rakun_runtime`'s
%%% supervision tree: the sidecars are shipped independently, per atom named in
%%% emitted output.
-module(rakun_autoconfig).

-export([auto_register/4, auto_provides/2, auto_provided/1,
         auto_names/0, auto_count/0, auto_conditions/1,
         auto_before/1, auto_after/1, auto_known/1,
         auto_decide/3, auto_state/1, auto_reason/1,
         auto_seal/1, auto_sealed/0, auto_order/0, auto_unseal/0,
         auto_reset/0, print_line/1]).

%% reachable for a test or a later front
-export([ensure/0, owner/1]).

-define(ENTRIES, rakun_ac_entries).   %% ordered_set: {Seq, Name, Conds, Before, After}
-define(INDEX, rakun_ac_index).       %% set:         {Name, Seq}
-define(PROVIDE, rakun_ac_provides). %% set:         {Name, TypeName}
-define(DECIDE, rakun_ac_decisions).  %% set:         {Name, State, Reason}
-define(FLAGS, rakun_ac_flags).       %% set:         {Key, Value}
-define(SEQ, rakun_ac_seq).           %% set:         {Name, Integer}
-define(OWNER, rakun_ac_owner).

%% ═══ lifecycle of the tables ════════════════════════════════════════════════

ensure() ->
    case ets:whereis(?ENTRIES) of
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
            _ = ets:new(?ENTRIES, [ordered_set | Common]),
            _ = ets:new(?INDEX, [set | Common]),
            _ = ets:new(?PROVIDE, [set | Common]),
            _ = ets:new(?DECIDE, [set | Common]),
            _ = ets:new(?FLAGS, [set | Common]),
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
to_bin(L) when is_list(L) -> list_to_binary(L);
to_bin(A) when is_atom(A) -> atom_to_binary(A, utf8).

join([]) -> <<>>;
join([H | T]) ->
    lists:foldl(fun(X, Acc) -> <<Acc/binary, ",", X/binary>> end,
                to_bin(H), [to_bin(X) || X <- T]).

%% ═══ registrations ══════════════════════════════════════════════════════════
%%
%% Append-only. A second registration of one name REPLACES the first in place
%% rather than appending a twin: a module loaded twice must not double a row,
%% and a row that appeared twice would make the report lie about the table's
%% size. The sequence is kept, so registration order is stable across a replace.

auto_register(Name, Conds, Before, After) ->
    ensure(),
    N = to_bin(Name),
    Seq = case ets:lookup(?INDEX, N) of
              [{_, S}] -> S;
              [] ->
                  Fresh = next_seq(entries),
                  true = ets:insert(?INDEX, {N, Fresh}),
                  Fresh
          end,
    true = ets:insert(?ENTRIES, {Seq, N, to_bin(Conds), to_bin(Before), to_bin(After)}),
    ets:info(?ENTRIES, size).

%% What an entry contributes to the registered set once it matches. It is NOT a
%% condition and therefore not a record of the condition blob: `auto_conditions`
%% has to answer the blob the annotations produced, verbatim, or it stops being
%% the comptime half's assertion point.
auto_provides(Name, TypeName) ->
    ensure(),
    true = ets:insert(?PROVIDE, {to_bin(Name), to_bin(TypeName)}),
    ets:info(?PROVIDE, size).

auto_provided(Name) ->
    ensure(),
    case ets:lookup(?PROVIDE, to_bin(Name)) of
        [{_, T}] -> T;
        [] -> <<>>
    end.

auto_names() ->
    ensure(),
    join([N || {_S, N, _C, _B, _A} <- ets:tab2list(?ENTRIES)]).

auto_count() ->
    ensure(),
    ets:info(?ENTRIES, size).

entry(Name) ->
    ensure(),
    N = to_bin(Name),
    case ets:lookup(?INDEX, N) of
        [{_, Seq}] ->
            case ets:lookup(?ENTRIES, Seq) of
                [E] -> E;
                [] -> none
            end;
        [] -> none
    end.

auto_conditions(Name) ->
    case entry(Name) of
        {_S, _N, C, _B, _A} -> C;
        none -> <<>>
    end.

auto_before(Name) ->
    case entry(Name) of
        {_S, _N, _C, B, _A} -> B;
        none -> <<>>
    end.

auto_after(Name) ->
    case entry(Name) of
        {_S, _N, _C, _B, A} -> A;
        none -> <<>>
    end.

auto_known(Name) ->
    entry(Name) =/= none.

%% ═══ decisions ══════════════════════════════════════════════════════════════

auto_decide(Name, State, Reason) ->
    ensure(),
    true = ets:insert(?DECIDE, {to_bin(Name), to_bin(State), to_bin(Reason)}),
    ets:info(?DECIDE, size).

auto_state(Name) ->
    ensure(),
    case ets:lookup(?DECIDE, to_bin(Name)) of
        [{_, S, _R}] -> S;
        [] -> <<>>
    end.

auto_reason(Name) ->
    ensure(),
    case ets:lookup(?DECIDE, to_bin(Name)) of
        [{_, _S, R}] -> R;
        [] -> <<>>
    end.

%% ═══ the seal ═══════════════════════════════════════════════════════════════
%%
%% The seal is what makes `autoConfigure()` idempotent and what lets the report
%% say "never called" instead of printing an empty table.

auto_seal(Order) ->
    ensure(),
    true = ets:insert(?FLAGS, {sealed, true}),
    true = ets:insert(?FLAGS, {order, to_bin(Order)}),
    1.

auto_sealed() ->
    ensure(),
    case ets:lookup(?FLAGS, sealed) of
        [{_, true}] -> true;
        _ -> false
    end.

auto_order() ->
    ensure(),
    case ets:lookup(?FLAGS, order) of
        [{_, O}] -> O;
        [] -> <<>>
    end.

%% Registrations survive; only the decisions and the seal are dropped. A test
%% re-applies over the same table, which is the shape every assertion wants.
auto_unseal() ->
    ensure(),
    true = ets:delete_all_objects(?DECIDE),
    true = ets:delete_all_objects(?FLAGS),
    0.

auto_reset() ->
    ensure(),
    true = ets:delete_all_objects(?PROVIDE),
    true = ets:delete_all_objects(?ENTRIES),
    true = ets:delete_all_objects(?INDEX),
    true = ets:delete_all_objects(?DECIDE),
    true = ets:delete_all_objects(?FLAGS),
    true = ets:insert(?SEQ, {entries, 0}),
    0.

%% ═══ the --debug printer ════════════════════════════════════════════════════
%%
%% `println` is a `libs/std` builtin with no erlang lowering: the emitted module
%% calls a bare local `println/1`, `erlc` refuses it, and the test runner's
%% `__bp_load_siblings/0` skips the whole module SILENTLY — every function in it
%% then answers `undef`, a diagnosis away from the cause. One line of host per
%% row costs less than a report that only prints on one target.

print_line(Line) ->
    io:format("~ts~n", [to_bin(Line)]),
    1.
