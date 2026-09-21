%%% rakun — the request context, BEAM half: the erlang twin of
%%% `src/request_context.mjs`.
%%%
%%% WHAT LIVES HERE AND WHY. botopink has no top-level mutable state and no
%%% mutable record field, so the request frame has to live in the host. And the
%%% frame is not pure: it carries a queue of deferred THUNKS and a memo table of
%%% arbitrary typed VALUES, neither of which a string table can hold. That is
%%% front 22's test rather than front 05's, so this front ships both host files.
%%%
%%% WHAT DOES *NOT* LIVE HERE. The phase table, the header wire grammar, the
%%% cookie grammar, the `Set-Cookie` serialization, the draft-mode signature and
%%% every refusal message are botopink, compiled to both targets. This module
%%% holds a keyed slot store, a keyed line list, a queue, a table and a counter.
%%%
%%% THE SCOPE. A request is served by a process, so the frame is the serving
%%% process's dictionary under ONE key. Process identity is NOT request identity
%%% — a keep-alive connection process serves many requests in sequence — so the
%%% frame carries an epoch and every handle minted from it carries the epoch it
%%% was minted with. That is the whole reason this module exists rather than a
%%% bare `erlang:put/2`.
%%%
%%% MODULE ATOM. `src/sidecars/rakun_request_context.erl`, never
%%% `src/request_context.erl`: `shipErlSidecars` skips any qualifier atom
%%% matching a module the build emitted, rakun emits `rakun/request_context`,
%%% and the skip is SILENT. Every rakun sidecar is `rakun_<name>.erl`.
%%%
%%% TABLE OWNERSHIP. Deferred work runs in a CHILD process, so its bookkeeping
%%% cannot live in the parent's dictionary and cannot live in the child's. It
%%% lives in ETS, owned by a dedicated process that does nothing but stay alive,
%%% the shape `rakun_file_router` already uses and for the same reason: an ETS
%%% table dies with its creator, and a registration runs in whatever process
%%% happened to get there first.
-module(rakun_request_context).

-export([begin_frame/1, end_frame/0, is_live/0, epoch/0, slot/1, put_slot/2]).
-export([queue_cookie/2, cookie_blob/0]).
-export([defer/1, defer_count/0, start_deferred/1, after_wait/1,
         after_stat/1, after_log/0, after_reset/0]).
-export([share_bump/1, share_count/1, share_put/2, share_get/1, share_reset/0,
         sleep/1]).

%% reachable for a test or a later front
-export([ensure/0, owner/1]).

-define(FRAME, rakun_request).       %% the ONE process-dictionary key
-define(SHARED, rakun_request_shared). %% set: {Key, Integer | Binary}
-define(OWNER, rakun_request_owner).
-define(AFTER, rakun_request_after).   %% process dict: [{Pid, Ref}] awaiting a DOWN
-define(BUDGET, rakun_request_budget). %% process dict: the per-child budget in ms
-define(REQID, rakun_request_reaped_id). %% process dict: the id the reap logs under

%% ═══ the shared area ═════════════════════════════════════════════════════════
%% Deferred children and memo loaders both write where the parent can read.

ensure() ->
    case ets:whereis(?SHARED) of
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
            _ = ets:new(?SHARED, [set, named_table, public,
                                  {read_concurrency, true}]),
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

%% ═══ the frame ═══════════════════════════════════════════════════════════════
%% One key, one map. The epoch is `erlang:unique_integer/1` under `monotonic`,
%% so two frames on one process never share one and the second is strictly
%% greater — which is what makes a handle captured across a keep-alive request
%% raise instead of writing a cookie into somebody else's response.

begin_frame(Id) ->
    ensure(),
    Epoch = erlang:unique_integer([monotonic, positive]),
    put(?FRAME, #{epoch => Epoch,
                  slots => #{<<"id">> => Id},
                  cookies => [],
                  deferred => [],
                  memo => #{}}),
    Epoch.

end_frame() ->
    erase(?FRAME),
    0.

is_live() ->
    is_map(get(?FRAME)).

epoch() ->
    case get(?FRAME) of
        #{epoch := E} -> E;
        _ -> 0
    end.

slot(Name) ->
    case get(?FRAME) of
        #{slots := S} -> maps:get(Name, S, <<>>);
        _ -> <<>>
    end.

put_slot(Name, Value) ->
    case get(?FRAME) of
        #{slots := S} = F -> put(?FRAME, F#{slots := S#{Name => Value}}), 0;
        _ -> 0
    end.

%% ═══ the queued `Set-Cookie` lines ═══════════════════════════════════════════
%% A keyed line list, insertion-ordered and replaced by key — the same primitive
%% `rakun_runtime:set_reply_header/2` already is, and for the same reason: that
%% one replaces by name, so it carries one `Set-Cookie` and no more. This module
%% does not know what a cookie looks like; it is handed a name and a finished
%% line.

queue_cookie(Name, Line) ->
    case get(?FRAME) of
        #{cookies := Cs} = F ->
            %% Replacing keeps the ORIGINAL position: a response whose headers
            %% reorder themselves because a value was rewritten is a response
            %% nobody can diff.
            Next = case lists:keyfind(Name, 1, Cs) of
                       false -> Cs ++ [{Name, Line}];
                       _ -> lists:keyreplace(Name, 1, Cs, {Name, Line})
                   end,
            put(?FRAME, F#{cookies := Next}),
            length(Next);
        _ -> 0
    end.

cookie_blob() ->
    case get(?FRAME) of
        #{cookies := Cs} -> join([L || {_N, L} <- Cs]);
        _ -> <<>>
    end.

join([]) -> <<>>;
join([H | T]) ->
    lists:foldl(fun(X, Acc) -> <<Acc/binary, "\n", X/binary>> end, H, T).

%% ═══ deferred work ═══════════════════════════════════════════════════════════
%% `after(work)` pushes a thunk on the frame. `start_deferred/1` — called by
%% `endRequest` — spawns one MONITORED child per thunk with a FROZEN copy of the
%% frame under phase `after`, then returns; the response is written next and
%% `after_wait/1` reaps. The reaping is where the budget is enforced: a child
%% that outlives it is killed and the kill is logged. Nothing else in the
%% connection process would reap these, so the drain is part of the dispatcher
%% contract, not an afterthought.
%%
%% The Pid/Ref list lives in the PARENT's dictionary under its own key, not in
%% the frame: `end_frame/0` erases the frame and the children outlive it, which
%% is the whole point.

defer(Work) ->
    case get(?FRAME) of
        #{deferred := Ds} = F ->
            Next = Ds ++ [Work],
            put(?FRAME, F#{deferred := Next}),
            length(Next);
        _ -> 0
    end.

defer_count() ->
    case get(?FRAME) of
        #{deferred := Ds} -> length(Ds);
        _ -> 0
    end.

start_deferred(TimeoutMs) ->
    ensure(),
    case get(?FRAME) of
        #{deferred := Ds, slots := Slots} = F ->
            Frozen = F#{slots := Slots#{<<"phase">> => <<"after">>},
                        deferred := [],
                        cookies := []},
            Children = [spawn_child(Frozen, W) || W <- Ds],
            put(?AFTER, pending() ++ Children),
            put(?BUDGET, TimeoutMs),
            %% The id is captured HERE, not read in the reap: by the time a
            %% child settles the frame is erased, and a deferred failure with
            %% no request to hang it on is a line nobody can act on.
            put(?REQID, maps:get(<<"id">>, Slots, <<>>)),
            _ = stat_bump(<<"started">>, length(Children)),
            length(Children);
        _ -> 0
    end.

spawn_child(Frozen, Work) ->
    spawn_monitor(fun() ->
        put(?FRAME, Frozen),
        Work(),
        ok
    end).

pending() ->
    case get(?AFTER) of
        undefined -> [];
        L -> L
    end.

%% Wait for every started child to settle, or for `Budget` ms to pass. A child
%% that outlives the PER-CHILD budget is killed; a child that raises is counted
%% and logged with the request id, and neither reaches the client, because the
%% response is already written.
after_wait(Budget) ->
    ensure(),
    Children = pending(),
    put(?AFTER, []),
    PerChild = case get(?BUDGET) of undefined -> Budget; B -> B end,
    Wait = case PerChild < Budget of true -> PerChild; false -> Budget end,
    lists:foldl(fun(C, Acc) -> Acc + reap(C, Wait) end, 0, Children).

reap({Pid, Ref}, Wait) ->
    receive
        {'DOWN', Ref, process, Pid, normal} ->
            _ = stat_bump(<<"ok">>, 1),
            1;
        {'DOWN', Ref, process, Pid, Reason} ->
            _ = stat_bump(<<"failed">>, 1),
            _ = log(<<"after: failed ">>, Reason),
            1
    after Wait ->
        exit(Pid, kill),
        receive {'DOWN', Ref, process, Pid, _} -> ok after 1000 -> ok end,
        _ = stat_bump(<<"killed">>, 1),
        _ = log(<<"after: killed ">>, {timeout, Wait}),
        1
    end.

%% The request id is carried in the log line because front 17 reads it: a
%% deferred failure with no request to hang it on is a line nobody can act on.
log(Prefix, Reason) ->
    Id = case get(?REQID) of undefined -> <<>>; I -> I end,
    Line = iolist_to_binary([Prefix, Id, <<" ">>,
                             io_lib:format("~0tp", [Reason])]),
    Old = case ets:lookup(?SHARED, log) of
              [{_, L}] -> L;
              [] -> <<>>
          end,
    Next = case Old of
               <<>> -> Line;
               _ -> <<Old/binary, "\n", Line/binary>>
           end,
    true = ets:insert(?SHARED, {log, Next}),
    0.

stat_bump(Name, By) ->
    ets:update_counter(?SHARED, {stat, Name}, {2, By}, {{stat, Name}, 0}).

after_stat(Name) ->
    ensure(),
    case ets:lookup(?SHARED, {stat, Name}) of
        [{_, N}] -> N;
        [] -> 0
    end.

after_log() ->
    ensure(),
    case ets:lookup(?SHARED, log) of
        [{_, L}] -> L;
        [] -> <<>>
    end.

after_reset() ->
    ensure(),
    put(?AFTER, []),
    erase(?BUDGET),
    true = ets:delete(?SHARED, log),
    [ets:delete(?SHARED, K) || {stat, _} = K <- [K0 || {K0, _} <- ets:tab2list(?SHARED), is_tuple(K0)]],
    0.

%% ═══ the shared scratch, and a blocking sleep ════════════════════════════════
%% A deferred child is a different PROCESS, so a counter it bumps cannot live in
%% either dictionary. ETS is where the parent can read it back.

share_bump(Key) ->
    ensure(),
    ets:update_counter(?SHARED, {share, Key}, {2, 1}, {{share, Key}, 0}).

share_count(Key) ->
    ensure(),
    case ets:lookup(?SHARED, {share, Key}) of
        [{_, N}] when is_integer(N) -> N;
        _ -> 0
    end.

share_put(Key, Value) ->
    ensure(),
    true = ets:insert(?SHARED, {{share, Key}, Value}),
    0.

share_get(Key) ->
    ensure(),
    case ets:lookup(?SHARED, {share, Key}) of
        [{_, V}] when is_binary(V) -> V;
        _ -> <<>>
    end.

share_reset() ->
    ensure(),
    [ets:delete(?SHARED, K) || {share, _} = K <- [K0 || {K0, _} <- ets:tab2list(?SHARED), is_tuple(K0)]],
    0.

sleep(Ms) when Ms > 0 ->
    timer:sleep(Ms),
    0;
sleep(_) ->
    0.
