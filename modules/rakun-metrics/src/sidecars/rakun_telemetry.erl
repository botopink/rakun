%%% rakun-metrics — the instrumentation bus (front 75 step 2).
%%%
%%% `:telemetry`'s three functions over an ETS handler table, because
%%% `telemetry` is a hex package and not OTP: `attach/4`, `detach/1`,
%%% `execute/3`, events named as atom lists (`[rakun, http, request, stop]`).
%%% When the real `telemetry` module is loaded, `attach/4` goes to it and
%%% `execute/3` calls it first; the local table still answers for handlers
%%% attached before it was loaded, so a handler receives an event exactly once
%%% whichever path attached it.
%%%
%%% `execute/3` with no handler is one `ets:lookup/2` in the caller and nothing
%%% else — no message, no process. A handler runs in the emitting process; one
%%% that raises is detached, its failure logged ONCE (the handler is gone after
%%% it), and the emitter never sees the raise.
%%%
%%% The atom is `rakun_telemetry`, never `telemetry`: the optional delegation
%%% to the real library stays unambiguous.

-module(rakun_telemetry).
-export([attach/4, detach/1, execute/3, handlers/0, failures/0, reset/0,
         attach_text/3, execute_text/3, owner_pid/0, real_loaded/0]).

-define(T, rakun_telemetry_handlers).  %% set: {Event, [{Id, Fun, Config}]} | {{id, Id}, Event}
-define(F, rakun_telemetry_failures).  %% ordered_set: {Seq, EventText, HandlerId, Reason}
-define(OWNER, rakun_telemetry_owner).

real_loaded() ->
    erlang:function_exported(telemetry, execute, 3).

attach(Id, Event, Fun, Config) ->
    case real_loaded() of
        true -> apply(telemetry, attach, [Id, Event, Fun, Config]);
        false ->
            ensure(),
            case ets:lookup(?T, {id, Id}) of
                [_] -> {error, already_exists};
                [] ->
                    Hs = case ets:lookup(?T, Event) of [{_, L}] -> L; [] -> [] end,
                    ets:insert(?T, [{Event, Hs ++ [{Id, Fun, Config}]}, {{id, Id}, Event}]),
                    ok
            end
    end.

detach(Id) ->
    _ = case real_loaded() of
            true -> try apply(telemetry, detach, [Id]) catch _:_ -> ok end;
            false -> ok
        end,
    ensure(),
    case ets:lookup(?T, {id, Id}) of
        [{_, Event}] ->
            Hs = case ets:lookup(?T, Event) of [{_, L}] -> L; [] -> [] end,
            case [H || {I, _, _} = H <- Hs, I =/= Id] of
                [] -> ets:delete(?T, Event);
                Kept -> ets:insert(?T, {Event, Kept})
            end,
            ets:delete(?T, {id, Id}),
            ok;
        [] -> {error, not_found}
    end.

execute(Event, Measurements, Metadata) ->
    _ = case real_loaded() of
            true -> try apply(telemetry, execute, [Event, Measurements, Metadata]) catch _:_ -> ok end;
            false -> ok
        end,
    case lookup(Event) of
        [] -> ok;
        Hs -> lists:foreach(fun(H) -> run(H, Event, Measurements, Metadata) end, Hs)
    end.

lookup(Event) ->
    try ets:lookup(?T, Event) of
        [{_, Hs}] -> Hs;
        [] -> []
    catch error:badarg -> []
    end.

run({Id, Fun, Config}, Event, Measurements, Metadata) ->
    try Fun(Event, Measurements, Metadata, Config)
    catch C:R ->
        _ = detach(Id),
        Text = event_text(Event),
        Reason = iolist_to_binary(io_lib:format("~p:~p", [C, R])),
        ets:insert(?F, {erlang:unique_integer([monotonic, positive]), Text, to_bin(Id), Reason}),
        logger:warning("rakun telemetry: handler ~ts on ~ts raised and was detached: ~ts",
                       [to_bin(Id), Text, Reason]),
        ok
    end.

%% ═══ the botopink face ═══════════════════════════════════════════════════════
%% An event is dotted text (`rakun.http.request.stop`); a botopink handler gets
%% the event text and the two maps as JSON.

attach_text(Id, EventText, Handler) ->
    Fun = fun(Ev, M, D, _C) -> Handler(event_text(Ev), json_of(M), json_of(D)) end,
    case attach(Id, event_atoms(EventText), Fun, #{}) of
        ok -> 1;
        _ -> 0
    end.

execute_text(EventText, MeasurementsJson, MetadataJson) ->
    execute(event_atoms(EventText), decode(MeasurementsJson), decode(MetadataJson)),
    0.

%% `id\tevent` per handler, sorted.
handlers() ->
    ensure(),
    lists:sort([iolist_to_binary([to_bin(Id), "\t", event_text(E)])
                || {E, Hs} <- ets:tab2list(?T), is_list(E), {Id, _, _} <- Hs]).

%% `event\thandler\treason` per failure, oldest first.
failures() ->
    ensure(),
    [iolist_to_binary([E, "\t", I, "\t", R]) || {_, E, I, R} <- ets:tab2list(?F)].

reset() ->
    ensure(),
    ets:delete_all_objects(?T),
    ets:delete_all_objects(?F),
    0.

owner_pid() ->
    ensure(),
    whereis(?OWNER).

%% ═══ helpers ═════════════════════════════════════════════════════════════════

event_atoms(Text) ->
    [binary_to_atom(S) || S <- binary:split(Text, <<".">>, [global]), S =/= <<>>].

event_text(Event) ->
    iolist_to_binary(lists:join(<<".">>, [atom_to_binary(A) || A <- Event])).

json_of(Map) ->
    try iolist_to_binary(json:encode(Map)) catch _:_ -> <<"{}">> end.

decode(<<>>) -> #{};
decode(Json) ->
    try json:decode(Json) of
        M when is_map(M) -> maps:fold(fun(K, V, Acc) -> Acc#{binary_to_atom(K) => V} end, #{}, M);
        _ -> #{}
    catch _:_ -> #{}
    end.

to_bin(B) when is_binary(B) -> B;
to_bin(A) when is_atom(A) -> atom_to_binary(A);
to_bin(T) -> iolist_to_binary(io_lib:format("~p", [T])).

ensure() ->
    case ets:whereis(?T) of
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
    after 5000 -> erlang:demonitor(Ref, [flush]), ok
    end.

owner(Caller) ->
    case (try erlang:register(?OWNER, self()) catch error:badarg -> false end) of
        true ->
            _ = ets:new(?T, [named_table, public, set, {read_concurrency, true}]),
            _ = ets:new(?F, [named_table, public, ordered_set]),
            Caller ! {?OWNER, ready},
            receive stop -> ok end;
        _ ->
            Caller ! {?OWNER, ready},
            ok
    end.
