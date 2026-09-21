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

%% reachable for a test or a later front
-export([ensure/0, owner/1]).

-define(FRAME, rakun_request).       %% the ONE process-dictionary key
-define(SHARED, rakun_request_shared). %% set: {Key, Integer | Binary}
-define(OWNER, rakun_request_owner).

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
