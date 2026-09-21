%%% rakun-validation — the host half, BEAM: the erlang twin of
%%% `src/validation_host.mjs`.
%%%
%%% WHAT LIVES HERE AND WHY. botopink has no top-level mutable state and no
%%% mutable record field, so two things live in the host: the SPI registry,
%%% which maps a name to a `Constraint` VALUE (no string table holds one), and
%%% the binding accumulator the `bind…` readers append to.
%%%
%%% WHAT DOES NOT LIVE HERE. Every constraint predicate, every message
%%% template, every refusal text, the constraint table and the report's JSON
%%% are botopink, compiled to both rows. This module holds a table and a list.
%%%
%%% THE SCOPE. The registry is global and outlives the registering process, so
%%% it is ETS owned by a dedicated process. The accumulator is REQUEST-scoped
%%% and a request is served by a process, so it is that process's dictionary:
%%% two concurrent requests cannot see each other's violations, which is a
%%% property of the store and not of a convention.
%%%
%%% MODULE ATOM. `src/sidecars/rakun_validation.erl`, never
%%% `src/validation.erl`: `shipErlSidecars` skips any qualifier atom matching a
%%% module the build emitted, and the skip is SILENT — the build would exit 0
%%% and the program would die with `undefined function validation:bind_push/1`.
-module(rakun_validation).

-export([register_constraint/2, has_constraint/1, constraint_of/1,
         put_code/2, code_of/1, registered_names/0, constraint_reset/0]).
-export([bind_push/1, bind_count/0, bind_drain/0, bind_reset/0, bind_isolated/0]).

%% reachable for a test or a later front
-export([ensure/0, owner/1]).

-define(REG, rakun_v_constraints).   %% set: {Name, Constraint}
-define(SEQ, rakun_v_seq).           %% ordered_set: {Seq, Name}
-define(INDEX, rakun_v_index).       %% set: {Name, Seq}
-define(COUNT, rakun_v_count).       %% set: {Key, Integer}
-define(CODES, rakun_v_codes).       %% set: {Name, Code}
-define(OWNER, rakun_v_owner).
-define(ACC, rakun_validation_acc).  %% process dictionary key

%% ═══ lifecycle of the tables ════════════════════════════════════════════════

ensure() ->
    case ets:whereis(?REG) of
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

owner(Caller) ->
    Won = try erlang:register(?OWNER, self()) catch _:_ -> false end,
    case Won of
        true ->
            Common = [named_table, public, {read_concurrency, true}],
            _ = ets:new(?REG, [set | Common]),
            _ = ets:new(?SEQ, [ordered_set | Common]),
            _ = ets:new(?INDEX, [set | Common]),
            _ = ets:new(?COUNT, [set | Common]),
            _ = ets:new(?CODES, [set | Common]),
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

to_bin(B) when is_binary(B) -> B;
to_bin(L) when is_list(L) -> list_to_binary(L);
to_bin(A) when is_atom(A) -> atom_to_binary(A, utf8).

%% ═══ the constraint registry ════════════════════════════════════════════════
%%
%% A second registration of one name REPLACES the first in place rather than
%% appending a twin: a module loaded twice must not double a row, and the
%% registration order stays stable across a replace.

register_constraint(Name, C) ->
    ensure(),
    N = to_bin(Name),
    case ets:lookup(?INDEX, N) of
        [] ->
            Seq = ets:update_counter(?COUNT, names, {2, 1}, {names, 0}),
            true = ets:insert(?INDEX, {N, Seq}),
            true = ets:insert(?SEQ, {Seq, N});
        _ -> ok
    end,
    true = ets:insert(?REG, {N, C}),
    ets:info(?REG, size).

has_constraint(Name) ->
    ensure(),
    ets:member(?REG, to_bin(Name)).

%% Guarded by `has_constraint` at every call site in `spi.bp`: an unregistered
%% name is a VIOLATION there, never a lookup that answers a stand-in here.
constraint_of(Name) ->
    ensure(),
    case ets:lookup(?REG, to_bin(Name)) of
        [{_, C}] -> C;
        [] -> undefined
    end.

put_code(Name, Code) ->
    ensure(),
    true = ets:insert(?CODES, {to_bin(Name), to_bin(Code)}),
    ets:info(?CODES, size).

code_of(Name) ->
    ensure(),
    case ets:lookup(?CODES, to_bin(Name)) of
        [{_, C}] -> C;
        [] -> <<>>
    end.

registered_names() ->
    ensure(),
    Names = [N || {_Seq, N} <- lists:sort(ets:tab2list(?SEQ)), ets:member(?REG, N)],
    case Names of
        [] -> <<>>;
        [H | T] -> lists:foldl(fun(X, Acc) -> <<Acc/binary, ",", X/binary>> end, H, T)
    end.

constraint_reset() ->
    ensure(),
    true = ets:delete_all_objects(?REG),
    true = ets:delete_all_objects(?SEQ),
    true = ets:delete_all_objects(?INDEX),
    true = ets:delete_all_objects(?COUNT),
    true = ets:delete_all_objects(?CODES),
    0.

%% ═══ the binding accumulator ════════════════════════════════════════════════
%%
%% The serving process's dictionary. Appending at the tail keeps the report in
%% binding order, which is the order the handler wrote its `bind…` calls in.

acc() ->
    case get(?ACC) of
        undefined -> [];
        L -> L
    end.

bind_push(V) ->
    L = acc(),
    put(?ACC, L ++ [V]),
    length(L) + 1.

bind_count() ->
    length(acc()).

bind_drain() ->
    L = acc(),
    erase(?ACC),
    L.

bind_reset() ->
    erase(?ACC),
    0.

%% The isolation claim, BEAM half, MEASURED rather than stated: a child process
%% pushes into its own accumulator and this process's count must not move. The
%% node twin answers the same `true` for a row that has no second scope.
bind_isolated() ->
    Before = bind_count(),
    Parent = self(),
    Pid = spawn(fun() ->
                    _ = bind_push(child_one),
                    _ = bind_push(child_two),
                    Parent ! {isolated, bind_count()}
                end),
    Ref = erlang:monitor(process, Pid),
    Child = receive
                {isolated, N} ->
                    erlang:demonitor(Ref, [flush]),
                    N;
                {'DOWN', Ref, process, Pid, _} -> -1
            after 5000 ->
                erlang:demonitor(Ref, [flush]),
                -1
            end,
    (Child =:= 2) andalso (bind_count() =:= Before).
