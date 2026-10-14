%% jhonstart — the UI file-convention registry, BEAM half (front 30 Step 10).
%%
%% The erlang twin of `../routes.mjs`. A registration is a module-load `val`,
%% so it runs in whatever process loaded the module, and a render reads the
%% registry from the request's process: the table cannot live in a process
%% dictionary. It is an ETS table owned by a dedicated process that does
%% nothing but stay alive (the server library's file-router registry is the shape), created
%% on first use under a registered name so a racing second caller finds it.
%%
%% The module atom is `jhonstart_routes`, never `routes`: `shipErlSidecars`
%% silently skips an atom that matches a module the build emitted.
-module(jhonstart_routes).

-export([register_page/2, register_layout/2, register_template/2,
         register_default/2, register_loading/2, register_error/2,
         register_not_found/2, table/0, has/1, lookup/2]).
-export([owner/1]).

-define(TAB, jhonstart_ui_routes).     %% ordered_set: {Seq, Record, Fun}
-define(SEQ, jhonstart_ui_routes_seq). %% set: {seq, N}
-define(OWNER, jhonstart_ui_routes_owner).

ensure() ->
    case ets:whereis(?TAB) of
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
            Common = [named_table, public, {read_concurrency, true}],
            _ = ets:new(?TAB, [ordered_set | Common]),
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

add(Record, Fun) ->
    ensure(),
    Seq = ets:update_counter(?SEQ, seq, {2, 1}, {seq, 0}),
    true = ets:insert(?TAB, {Seq, Record, Fun}),
    ets:info(?TAB, size).

register_page(R, F) -> add(R, F).
register_layout(R, F) -> add(R, F).
register_template(R, F) -> add(R, F).
register_default(R, F) -> add(R, F).
register_loading(R, F) -> add(R, F).
register_error(R, F) -> add(R, F).
register_not_found(R, F) -> add(R, F).

table() ->
    ensure(),
    join([R || {_Seq, R, _F} <- ets:tab2list(?TAB)]).

join([]) -> <<>>;
join([H | T]) -> lists:foldl(fun(X, Acc) -> <<Acc/binary, "\n", X/binary>> end, H, T).

has(Record) ->
    ensure(),
    lists:any(fun({_S, R, _F}) -> R =:= Record end, ets:tab2list(?TAB)).

lookup(Record, Fallback) ->
    ensure(),
    case [F || {_S, R, F} <- ets:tab2list(?TAB), R =:= Record] of
        [F | _] -> F;
        [] -> Fallback
    end.
