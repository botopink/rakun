%%% rakun-websocket — the BEAM half of front 20.
%%%
%%% WHAT LIVES HERE AND WHY. Only what botopink cannot hold or reach:
%%%
%%%   * the UPGRADE: front 04's connection process (`rakun_runtime`) runs the
%%%     request through the application's dispatcher as usual and, when it
%%%     carries `Upgrade: websocket` and this module installed its hook
%%%     (`install/0` → the `rakun_upgrade_hook` persistent term), hands the
%%%     socket and the dispatcher's answer to `upgrade/5`. That answer decides:
%%%     `101` (the endpoint's own route answered, so front 07's chain and front
%%%     10's security let it through) is a handshake; `401`/`403` on a
%%%     registered path is a handshake closed at once with `1008`, no handler
%%%     reached; an unregistered path is `404`; anything else is written as the
%%%     HTTP answer it is. The connection process BECOMES the WebSocket
%%%     connection: one supervised process per connection (`rakun_conn_sup`);
%%%   * the frame codec (RFC 6455): masked client frames in, unmasked server
%%%     frames out, text only (a binary frame closes with `1003`), the
%%%     `max-frame-bytes` refusal (`1009`), ping/pong heartbeats and the idle
%%%     close, the outbound cap (`1013`);
%%%   * the session table (id → pid, principal, path) and the topics over OTP
%%%     `pg` (scope `rakun_ws`), which is distribution-aware and forgets a dead
%%%     member by itself;
%%%   * the counters the health report reads, and the close log the tests read;
%%%   * an in-process test CLIENT (`client_*`) over `gen_tcp`, so the suite
%%%     needs no browser.
%%%
%%% WHAT DOES NOT LIVE HERE. The endpoint registry's meaning, the duplicate
%%% refusal, the settings and their defaults, the envelope and every message
%%% text are botopink.
%%%
%%% MODULE ATOM. `rakun_websocket`, never `websocket`.
-module(rakun_websocket).

-export([register_endpoint/5, endpoints/0, duplicates/0, reset/0,
         install/0, uninstall/0, installed/0, upgrade/5,
         send/2, close/3, subscribe/2, unsubscribe/2, broadcast/2, sessions_on/1,
         session_ids/0, open_count/0, topic_count/0, refused_count/0, closed_with/1,
         max_queue_seen/0, note_principal/1, accepting/0, session_supervised/1,
         client_connect/3, client_send/2, client_send_binary/2, client_recv/2,
         client_pause/1, client_autopong/2, client_close/2,
         two_node_broadcast/2, wide/1]).
-export([remote_subscriber/2]).

-define(ENDPOINTS, rakun_ws_endpoints). %% ordered_set {Seq, Path, TypeName, OnOpen, OnMessage, OnClose}
-define(SESSIONS, rakun_ws_sessions).   %% set {Id, Pid, Principal, Path}
-define(STATE, rakun_ws_state).         %% set {Key, Value}: overflow flags, counters, close log
-define(SCOPE, rakun_ws).
-define(GUID, <<"258EAFA5-E914-47DA-95CA-C5AB0DC85B11">>).

%% ═══ the endpoint registry ═══════════════════════════════════════════════════

register_endpoint(Path, TypeName, OnOpen, OnMessage, OnClose) ->
    ensure(),
    true = ets:insert(?ENDPOINTS, {seq(), Path, TypeName, OnOpen, OnMessage, OnClose}),
    0.

%% `path|type`, registration order.
endpoints() ->
    ensure(),
    [iolist_to_binary([P, "|", T]) || {_, P, T, _, _, _} <- ets:tab2list(?ENDPOINTS)].

%% `path|first|second` for every path registered twice.
duplicates() ->
    ensure(),
    All = [{P, T} || {_, P, T, _, _, _} <- ets:tab2list(?ENDPOINTS)],
    dups(All, #{}, []).

dups([], _, Acc) -> lists:reverse(Acc);
dups([{P, T} | Rest], Seen, Acc) ->
    case maps:find(P, Seen) of
        {ok, First} -> dups(Rest, Seen, [iolist_to_binary([P, "|", First, "|", T]) | Acc]);
        error -> dups(Rest, Seen#{P => T}, Acc)
    end.

endpoint(Path) ->
    case [{O, M, C} || {_, P, _, O, M, C} <- ets:tab2list(?ENDPOINTS), P =:= Path] of
        [E | _] -> E;
        [] -> undefined
    end.

reset() ->
    ensure(),
    [exit(Pid, kill) || {_, Pid, _, _} <- ets:tab2list(?SESSIONS)],
    [true = ets:delete_all_objects(T) || T <- [?ENDPOINTS, ?SESSIONS, ?STATE]],
    0.

%% ═══ the hook ════════════════════════════════════════════════════════════════

install() ->
    ensure(),
    persistent_term:put(rakun_upgrade_hook, fun ?MODULE:upgrade/5),
    0.

uninstall() ->
    _ = persistent_term:erase(rakun_upgrade_hook),
    0.

installed() ->
    persistent_term:get(rakun_upgrade_hook, undefined) =/= undefined.

%% Accepting upgrades: the hook installed and front 04's listener alive.
accepting() ->
    installed() andalso
        lists:any(fun({rakun_listener, P, _, _}) -> is_pid(P) andalso is_process_alive(P); (_) -> false end,
                  try supervisor:which_children(rakun_sup) catch _:_ -> [] end).

%% The endpoint's route runs inside the request (after the chain), so it can
%% read the principal front 10 established and leave it for the upgrade.
note_principal(Name) ->
    put(rakun_ws_principal, Name),
    0.

setting(Key, Default) ->
    case rakun_runtime:prop(<<"rakun.websocket.", Key/binary>>) of
        <<>> -> Default;
        V -> try binary_to_integer(string:trim(V)) catch _:_ -> Default end
    end.

upgrade(Sock, Mod0, Path, Headers, #{status := Status, body := Body}) ->
    ensure(),
    Mod = case Mod0 of ssl -> ssl; _ -> gen_tcp end,
    case endpoint(Path) of
        undefined -> http(Mod, Sock, 404, <<"no WebSocket endpoint at this path">>);
        {OnOpen, OnMessage, OnClose} ->
            Key = maps:get(<<"sec-websocket-key">>, Headers, <<>>),
            Version = maps:get(<<"sec-websocket-version">>, Headers, <<>>),
            Conn = string:lowercase(maps:get(<<"connection">>, Headers, <<>>)),
            Offered = [string:trim(P) || P <- binary:split(maps:get(<<"sec-websocket-protocol">>, Headers, <<>>), <<",">>, [global]), string:trim(P) =/= <<>>],
            Max = setting(<<"max-connections">>, 10000),
            if
                Key =:= <<>>; Version =/= <<"13">> ->
                    http(Mod, Sock, 400, <<"a WebSocket upgrade needs Sec-WebSocket-Key and Sec-WebSocket-Version: 13">>);
                Offered =/= [] ->
                    case lists:member(<<"rakun.v1">>, Offered) of
                        true -> handshake(Mod, Sock, Key, <<"rakun.v1">>, Status, Body, Path, Conn, Max, {OnOpen, OnMessage, OnClose});
                        false -> http(Mod, Sock, 400, <<"unknown WebSocket subprotocol: this server speaks rakun.v1">>)
                    end;
                true ->
                    handshake(Mod, Sock, Key, <<>>, Status, Body, Path, Conn, Max, {OnOpen, OnMessage, OnClose})
            end
    end.

handshake(Mod, Sock, Key, Proto, Status, Body, Path, _Conn, Max, Handlers) ->
    case Status of
        101 ->
            case open_count() >= Max of
                true ->
                    bump(refused),
                    http(Mod, Sock, 503, <<"the WebSocket connection cap is reached">>);
                false ->
                    accept(Mod, Sock, Key, Proto),
                    run(Mod, Sock, Path, Handlers)
            end;
        S when S =:= 401; S =:= 403 ->
            accept(Mod, Sock, Key, Proto),
            _ = Mod:send(Sock, frame(8, <<1008:16, "unauthorized">>)),
            log_close(<<"refused">>, 1008),
            ok;
        _ ->
            http(Mod, Sock, Status, Body)
    end.

accept(Mod, Sock, Key, Proto) ->
    Accept = base64:encode(crypto:hash(sha, <<Key/binary, ?GUID/binary>>)),
    ProtoLine = case Proto of <<>> -> <<>>; _ -> [<<"Sec-WebSocket-Protocol: ">>, Proto, <<"\r\n">>] end,
    ok = Mod:send(Sock, [<<"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ">>,
                         Accept, <<"\r\n">>, ProtoLine, <<"\r\n">>]).

http(Mod, Sock, Status, Body) ->
    _ = Mod:send(Sock, [<<"HTTP/1.1 ">>, integer_to_binary(Status), <<" ">>, phrase(Status),
                        <<"\r\nContent-Length: ">>, integer_to_binary(byte_size(Body)),
                        <<"\r\nConnection: close\r\n\r\n">>, Body]),
    ok.

phrase(400) -> <<"Bad Request">>;
phrase(401) -> <<"Unauthorized">>;
phrase(403) -> <<"Forbidden">>;
phrase(404) -> <<"Not Found">>;
phrase(503) -> <<"Service Unavailable">>;
phrase(_) -> <<"Error">>.

%% ═══ the connection ══════════════════════════════════════════════════════════

run(Mod, Sock, Path, {OnOpen, OnMessage, OnClose}) ->
    Id = iolist_to_binary(["ws-", integer_to_binary(seq())]),
    Principal = case get(rakun_ws_principal) of undefined -> <<>>; P -> P end,
    true = ets:insert(?SESSIONS, {Id, self(), Principal, Path}),
    _ = pg:join(?SCOPE, all, self()),
    Opts = [{packet, raw}, {send_timeout, 500}, {send_timeout_close, false}, {sndbuf, 65536},
            {high_watermark, 4194304}, {low_watermark, 2097152}],
    _ = case Mod of ssl -> ssl:setopts(Sock, Opts); _ -> inet:setopts(Sock, Opts) end,
    Heartbeat = setting(<<"heartbeat-seconds">>, 30) * 1000,
    Idle = setting(<<"idle-timeout-seconds">>, 90) * 1000,
    MaxFrame = setting(<<"max-frame-bytes">>, 65536),
    Cap = setting(<<"max-outbound-queue">>, 1000),
    put(rakun_ws_cap, Cap),
    erlang:send_after(Heartbeat, self(), ws_heartbeat),
    S = #{mod => Mod, sock => Sock, id => Id, principal => Principal, path => Path,
          buf => <<>>, last => now_ms(), heartbeat => Heartbeat, idle => Idle,
          max_frame => MaxFrame, on_message => OnMessage, on_close => OnClose},
    case call_handler(fun() -> OnOpen(Id, Principal, Path) end) of
        ok -> active(S), loop(S);
        error -> finish(S, 1011, <<"handler error">>)
    end.

active(#{mod := ssl, sock := Sock}) -> ssl:setopts(Sock, [{active, once}]);
active(#{sock := Sock}) -> inet:setopts(Sock, [{active, once}]).

loop(S = #{sock := Sock, id := Id}) ->
    case overflowed(Id) of
        true -> finish(S, 1013, <<"outbound queue over the cap">>);
        false ->
            receive
                {Tag, Sock, Data} when Tag =:= tcp; Tag =:= ssl ->
                    frames(S#{buf := <<(maps:get(buf, S))/binary, Data/binary>>, last := now_ms()});
                {Tag, Sock} when Tag =:= tcp_closed; Tag =:= ssl_closed ->
                    finish_silent(S, 1006, <<"the peer went away">>);
                {ws_out, Frame} ->
                    case writable(S) of
                        false -> finish(S, 1013, <<"outbound queue over the cap">>);
                        true ->
                            case (maps:get(mod, S)):send(Sock, Frame) of
                                ok -> loop(S);
                                {error, timeout} -> loop(S);
                                {error, _} -> finish_silent(S, 1006, <<"send failed">>)
                            end
                    end;
                {ws_close, Code, Reason} ->
                    finish(S, Code, Reason);
                ws_heartbeat ->
                    #{last := Last, idle := IdleMs, heartbeat := Hb} = S,
                    case now_ms() - Last >= IdleMs of
                        true -> finish(S, 1001, <<"idle timeout">>);
                        false ->
                            _ = (maps:get(mod, S)):send(Sock, frame(9, <<>>)),
                            erlang:send_after(Hb, self(), ws_heartbeat),
                            loop(S)
                    end
            end
    end.

%% A peer that stops reading fills the kernel's buffers, and a `send` on a
%% full socket parks the process where it can see nothing. So a frame goes out
%% only while the driver holds nothing unsent (the kernel took everything so
%% far — the high watermark is raised so a send never parks); otherwise the process
%% waits, still watching its overflow flag: the frames behind it pile up in the
%% mailbox, `push/3` stops at the cap and flags it, and this answers false.
writable(S = #{sock := Sock, id := Id}) ->
    case overflowed(Id) of
        true -> false;
        false ->
            case pending(S) > 0 of
                false -> true;
                true -> receive after 20 -> ok end, writable(S#{sock := Sock})
            end
    end.

pending(#{mod := ssl}) -> 0;
pending(#{sock := Sock}) ->
    case inet:getstat(Sock, [send_pend]) of
        {ok, [{send_pend, N}]} -> N;
        _ -> 0
    end.

frames(S = #{buf := Buf, max_frame := MaxFrame}) ->
    case parse(Buf, MaxFrame) of
        more -> active(S), loop(S);
        too_big -> finish(S, 1009, <<"frame over max-frame-bytes">>);
        {Op, Payload, Rest} ->
            S2 = S#{buf := Rest},
            case Op of
                1 ->
                    #{on_message := OnMessage, id := Id, principal := P, path := Path} = S2,
                    case call_handler(fun() -> OnMessage(Id, P, Path, Payload) end) of
                        ok -> frames(S2);
                        error -> finish(S2, 1011, <<"handler error">>)
                    end;
                2 -> finish(S2, 1003, <<"binary frames are refused: rakun.v1 carries text only">>);
                8 ->
                    {Code, Reason} = case Payload of
                                         <<C:16, R/binary>> -> {C, R};
                                         _ -> {1000, <<>>}
                                     end,
                    finish(S2, Code, Reason);
                9 -> _ = (maps:get(mod, S2)):send(maps:get(sock, S2), frame(10, Payload)), frames(S2);
                10 -> frames(S2);
                _ -> frames(S2)
            end
    end.

call_handler(F) ->
    try F() of _ -> ok
    catch _:_ -> error
    end.

finish(S = #{mod := Mod, sock := Sock}, Code, Reason) ->
    leave_all(),
    %% A peer that is not reading gets no close frame (it could not take it);
    %% its socket is reset instead of lingering on the unsent bytes.
    _ = case pending(S) > 0 of
            true -> inet:setopts(Sock, [{linger, {true, 0}}]);
            false -> Mod:send(Sock, frame(8, <<Code:16, Reason/binary>>))
        end,
    finish_silent(S, Code, Reason).

finish_silent(#{mod := Mod, sock := Sock, id := Id, principal := P, path := Path, on_close := OnClose}, Code, Reason) ->
    leave_all(),
    _ = call_handler(fun() -> OnClose(Id, P, Path, Code, Reason) end),
    log_close(Id, Code),
    true = ets:delete(?SESSIONS, Id),
    true = ets:delete(?STATE, {overflow, Id}),
    _ = Mod:close(Sock),
    ok.

%% Leave every group NOW — before the close frame goes out — not when `pg`
%% sees the process exit: a broadcast after the peer saw the close must not
%% count this session.
leave_all() ->
    _ = [pg:leave(?SCOPE, G, self()) || G <- pg:which_groups(?SCOPE),
                                         lists:member(self(), pg:get_local_members(?SCOPE, G))],
    ok.

log_close(Id, Code) ->
    true = ets:insert(?STATE, {{closed, Id}, Code}),
    true = ets:insert(?STATE, {{closed, last}, Code}).

closed_with(Id) ->
    ensure(),
    case ets:lookup(?STATE, {closed, Id}) of
        [{_, C}] -> C;
        [] -> 0
    end.

%% ═══ frames ══════════════════════════════════════════════════════════════════

frame(Op, Payload) ->
    Len = byte_size(Payload),
    Head = if
               Len < 126 -> <<1:1, 0:3, Op:4, 0:1, Len:7>>;
               Len < 65536 -> <<1:1, 0:3, Op:4, 0:1, 126:7, Len:16>>;
               true -> <<1:1, 0:3, Op:4, 0:1, 127:7, Len:64>>
           end,
    [Head, Payload].

masked_frame(Op, Payload) ->
    Len = byte_size(Payload),
    Mask = crypto:strong_rand_bytes(4),
    Head = if
               Len < 126 -> <<1:1, 0:3, Op:4, 1:1, Len:7>>;
               Len < 65536 -> <<1:1, 0:3, Op:4, 1:1, 126:7, Len:16>>;
               true -> <<1:1, 0:3, Op:4, 1:1, 127:7, Len:64>>
           end,
    [Head, Mask, unmask(Payload, Mask)].

parse(<<_Fin:1, _:3, Op:4, M:1, L7:7, Rest/binary>>, Max) ->
    {Len, Rest2} = case L7 of
                       126 -> case Rest of <<L:16, R/binary>> -> {L, R}; _ -> {more, Rest} end;
                       127 -> case Rest of <<L:64, R/binary>> -> {L, R}; _ -> {more, Rest} end;
                       _ -> {L7, Rest}
                   end,
    if
        Len =:= more -> more;
        Len > Max -> too_big;
        true ->
            MaskLen = M * 4,
            case Rest2 of
                <<Mask:MaskLen/binary, Payload:Len/binary, After/binary>> ->
                    {Op, case M of 1 -> unmask(Payload, Mask); 0 -> Payload end, After};
                _ -> more
            end
    end;
parse(_, _) -> more.

unmask(Payload, Mask) ->
    Size = byte_size(Payload),
    Rep = binary:copy(Mask, Size div 4 + 1),
    <<M:Size/binary, _/binary>> = Rep,
    crypto:exor(Payload, M).

%% ═══ sessions, topics, broadcast ═════════════════════════════════════════════

pid_of(Id) ->
    case ets:lookup(?SESSIONS, Id) of
        [{_, Pid, _, _}] -> Pid;
        [] -> undefined
    end.

%% Queues one text frame to a connection unless its mailbox is at the cap, in
%% which case the connection is flagged and closes itself with 1013. Answers 1
%% when queued.
push(Pid, Id, Text) ->
    Cap = case ets:lookup(?STATE, cap) of [{_, C}] -> C; [] -> 1000 end,
    Queue = case erlang:process_info(Pid, message_queue_len) of
                {message_queue_len, N} -> N;
                undefined -> -1
            end,
    record_queue(Queue),
    if
        Queue < 0 -> 0;
        Queue >= Cap -> true = ets:insert(?STATE, {{overflow, Id}, true}), 0;
        true -> Pid ! {ws_out, frame(1, Text)}, 1
    end.

record_queue(N) ->
    case ets:lookup(?STATE, max_queue) of
        [{_, M}] when M >= N -> ok;
        _ -> true = ets:insert(?STATE, {max_queue, N})
    end.

max_queue_seen() ->
    ensure(),
    case ets:lookup(?STATE, max_queue) of [{_, M}] -> M; [] -> 0 end.

overflowed(Id) ->
    ets:member(?STATE, {overflow, Id}).

send(Id, Text) ->
    ensure(),
    set_cap(),
    case pid_of(Id) of
        undefined -> 0;
        Pid -> push(Pid, Id, Text)
    end.

close(Id, Code, Reason) ->
    ensure(),
    case pid_of(Id) of
        undefined -> 0;
        Pid -> Pid ! {ws_close, Code, Reason}, 1
    end.

set_cap() ->
    true = ets:insert(?STATE, {cap, setting(<<"max-outbound-queue">>, 1000)}).

subscribe(Id, Topic) ->
    ensure(),
    case pid_of(Id) of
        undefined -> 0;
        Pid ->
            case lists:member(Pid, pg:get_local_members(?SCOPE, {topic, Topic})) of
                true -> 0;
                false -> ok = pg:join(?SCOPE, {topic, Topic}, Pid), 1
            end
    end.

unsubscribe(Id, Topic) ->
    ensure(),
    case pid_of(Id) of
        undefined -> 0;
        Pid ->
            case lists:member(Pid, pg:get_local_members(?SCOPE, {topic, Topic})) of
                true -> _ = pg:leave(?SCOPE, {topic, Topic}, Pid), 1;
                false -> 0
            end
    end.

%% Fire-and-forget to every member of the topic on every connected node;
%% answers how many frames were queued.
broadcast(Topic, Text) ->
    ensure(),
    set_cap(),
    Members = pg:get_members(?SCOPE, {topic, Topic}),
    lists:sum([case node(Pid) =:= node() of
                   true ->
                       case [I || {I, P, _, _} <- ets:tab2list(?SESSIONS), P =:= Pid] of
                           [Id | _] -> push(Pid, Id, Text);
                           [] -> Pid ! {ws_out, frame(1, Text)}, 1
                       end;
                   false -> Pid ! {ws_out, frame(1, Text)}, 1
               end || Pid <- Members]).

sessions_on(Topic) ->
    ensure(),
    length(pg:get_members(?SCOPE, {topic, Topic})).

%% The session's process is a child of front 04's `rakun_conn_sup`.
session_supervised(Id) ->
    ensure(),
    case pid_of(Id) of
        undefined -> false;
        Pid -> lists:any(fun({_, P, _, _}) -> P =:= Pid end, supervisor:which_children(rakun_conn_sup))
    end.

session_ids() ->
    ensure(),
    lists:sort([I || {I, _, _, _} <- ets:tab2list(?SESSIONS)]).

open_count() ->
    ensure(),
    ets:info(?SESSIONS, size).

topic_count() ->
    ensure(),
    length([G || {topic, _} = G <- pg:which_groups(?SCOPE), pg:get_members(?SCOPE, G) =/= []]).

refused_count() ->
    ensure(),
    case ets:lookup(?STATE, refused) of [{_, N}] -> N; [] -> 0 end.

bump(Key) ->
    ets:update_counter(?STATE, Key, {2, 1}, {Key, 0}).

%% ═══ two nodes ═══════════════════════════════════════════════════════════════
%%
%% Starts a peer node sharing this code path, joins a subscriber there to
%% `Topic`, broadcasts `Text` from here and answers `"<count>|<what the remote
%% subscriber received>"`, or `"skipped: <why>"` when this runner cannot start
%% a distributed peer.

two_node_broadcast(Topic, Text) ->
    ensure(),
    try
        case node() of
            nonode@nohost ->
                _ = os:cmd("epmd -daemon"),
                {ok, _} = net_kernel:start([list_to_atom("rakun_ws_" ++ integer_to_list(erlang:unique_integer([positive]))), shortnames]);
            _ -> ok
        end,
        {ok, Peer, Node} = peer:start_link(#{name => peer:random_name(), args => ["-setcookie", atom_to_list(erlang:get_cookie())]}),
        try
            true = rpc:call(Node, code, set_path, [code:get_path()]),
            %% The sidecar is compiled from source at run time and has no
            %% `.beam` on the path: compile the same source on the peer.
            Source = proplists:get_value(source, ?MODULE:module_info(compile)),
            {ok, ?MODULE, Bin} = rpc:call(Node, compile, file, [Source, [binary]]),
            {module, ?MODULE} = rpc:call(Node, code, load_binary, [?MODULE, Source, Bin]),
            _ = rpc:call(Node, pg, start, [?SCOPE]),
            Self = self(),
            Remote = erlang:spawn(Node, ?MODULE, remote_subscriber, [Topic, Self]),
            receive {remote_joined, Remote} -> ok after 5000 -> erlang:error(remote_join_timeout) end,
            wait_members(Topic, 50),
            Count = broadcast(Topic, Text),
            Got = receive {remote_got, Data} -> Data after 5000 -> <<"nothing">> end,
            iolist_to_binary([integer_to_binary(Count), "|", Got])
        after
            peer:stop(Peer)
        end
    catch C:E ->
        iolist_to_binary(io_lib:format("skipped: ~p:~p", [C, E]))
    end.

wait_members(_Topic, 0) -> ok;
wait_members(Topic, N) ->
    case [P || P <- pg:get_members(?SCOPE, {topic, Topic}), node(P) =/= node()] of
        [] -> receive after 20 -> wait_members(Topic, N - 1) end;
        _ -> ok
    end.

remote_subscriber(Topic, Parent) ->
    ok = pg:join(?SCOPE, {topic, Topic}, self()),
    Parent ! {remote_joined, self()},
    receive
        {ws_out, Frame} ->
            <<_:16, Payload/binary>> = iolist_to_binary(Frame),
            Parent ! {remote_got, Payload}
    after 10000 -> ok
    end.

%% ═══ the test client ═════════════════════════════════════════════════════════

%% Connects to 127.0.0.1:Port, sends the upgrade for `Path` with `Extra`
%% header lines (`Name: Value`), and answers `"<status>|<client>"` — the
%% client handle only when the status is 101.
client_connect(Port, Path, Extra) ->
    ensure(),
    Self = self(),
    Pid = spawn(fun() -> client_init(Self, Port, Path, Extra) end),
    receive {Pid, client_ready, Status} -> iolist_to_binary([integer_to_binary(Status), "|", client_name(Pid, Status)])
    after 5000 -> <<"0|">>
    end.

client_name(Pid, 101) ->
    Name = iolist_to_binary(["c", integer_to_binary(seq())]),
    true = ets:insert(?STATE, {{client, Name}, Pid}),
    Name;
client_name(_, _) -> <<>>.

client_pid(Name) ->
    case ets:lookup(?STATE, {client, Name}) of
        [{_, P}] -> P;
        [] -> undefined
    end.

client_init(Parent, Port, Path, Extra) ->
    {ok, S} = gen_tcp:connect("127.0.0.1", Port, [binary, {active, false}, {recbuf, 4096}, {sndbuf, 4096}]),
    Key = base64:encode(crypto:strong_rand_bytes(16)),
    ok = gen_tcp:send(S, [<<"GET ">>, Path, <<" HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: ">>,
                          Key, <<"\r\nSec-WebSocket-Version: 13\r\n">>, [[E, <<"\r\n">>] || E <- Extra], <<"\r\n">>]),
    {Head, Rest} = client_head(S, <<>>),
    [StatusLine | _] = binary:split(Head, <<"\r\n">>),
    [_, Code | _] = binary:split(StatusLine, <<" ">>, [global]),
    Status = binary_to_integer(Code),
    Parent ! {self(), client_ready, Status},
    case Status of
        101 -> client_loop(#{sock => S, buf => Rest, events => [], paused => false, autopong => true});
        _ -> gen_tcp:close(S)
    end.

client_head(S, Acc) ->
    case binary:split(Acc, <<"\r\n\r\n">>) of
        [H, R] -> {H, R};
        _ -> {ok, D} = gen_tcp:recv(S, 0, 5000), client_head(S, <<Acc/binary, D/binary>>)
    end.

client_loop(C = #{sock := S, paused := Paused}) ->
    C1 = client_frames(C),
    _ = case Paused of false -> inet:setopts(S, [{active, once}]); true -> ok end,
    receive
        {tcp, S, Data} -> client_loop(C1#{buf := <<(maps:get(buf, C1))/binary, Data/binary>>});
        {tcp_closed, S} -> client_loop(client_event(C1#{paused := true}, <<"closed">>));
        {send, Op, Payload} -> _ = gen_tcp:send(S, masked_frame(Op, Payload)), client_loop(C1);
        pause -> client_loop(C1#{paused := true});
        {autopong, On} -> client_loop(C1#{autopong := On});
        {poll, From, Ref} ->
            case maps:get(events, C1) of
                [E | Es] -> From ! {Ref, E}, client_loop(C1#{events := Es});
                [] -> From ! {Ref, empty}, client_loop(C1)
            end;
        stop -> gen_tcp:close(S)
    end.

client_frames(C = #{buf := Buf, sock := S, autopong := Auto}) ->
    case parse(Buf, 16#7FFFFFFF) of
        {1, P, R} -> client_frames(client_event(C#{buf := R}, <<"text:", P/binary>>));
        {8, <<Code:16, Reason/binary>>, R} ->
            client_frames(client_event(C#{buf := R}, iolist_to_binary(["close:", integer_to_binary(Code), ":", Reason])));
        {8, _, R} -> client_frames(client_event(C#{buf := R}, <<"close:1005:">>));
        {9, P, R} ->
            case Auto of
                true -> _ = gen_tcp:send(S, masked_frame(10, P));
                false -> ok
            end,
            client_frames(client_event(C#{buf := R}, <<"ping">>));
        {_, _, R} -> client_frames(C#{buf := R});
        _ -> C
    end.

client_event(C = #{events := Es}, E) -> C#{events := Es ++ [E]}.

client_send(Name, Text) -> client_cmd(Name, {send, 1, Text}).
client_send_binary(Name, Bytes) -> client_cmd(Name, {send, 2, Bytes}).
client_pause(Name) -> client_cmd(Name, pause).
client_autopong(Name, On) -> client_cmd(Name, {autopong, On}).
client_close(Name, Code) -> client_cmd(Name, {send, 8, <<Code:16>>}).

client_cmd(Name, Msg) ->
    case client_pid(Name) of
        undefined -> 0;
        P -> P ! Msg, 1
    end.

%% The next event the client saw: `text:<payload>`, `close:<code>:<reason>`,
%% `ping`, `closed` (the socket), or `none` after `Ms`. Pings are skipped
%% unless nothing else arrives.
client_recv(Name, Ms) ->
    case client_pid(Name) of
        undefined -> <<"none">>;
        P -> client_poll(P, now_ms() + Ms)
    end.

client_poll(P, Deadline) ->
    Ref = make_ref(),
    P ! {poll, self(), Ref},
    Reply = receive {Ref, R} -> R after 1000 -> empty end,
    case Reply of
        <<"ping">> -> client_poll(P, Deadline);
        empty ->
            case now_ms() >= Deadline of
                true -> <<"none">>;
                false -> receive after 10 -> client_poll(P, Deadline) end
            end;
        E -> E
    end.

wide(N) -> N.

%% ═══ the tables ══════════════════════════════════════════════════════════════

now_ms() -> erlang:monotonic_time(millisecond).

seq() -> erlang:unique_integer([monotonic, positive]).

ensure() ->
    case ets:whereis(?ENDPOINTS) of
        undefined -> boot();
        _ -> ok
    end.

boot() ->
    Caller = self(),
    Pid = spawn(fun() ->
                        case catch erlang:register(rakun_websocket_owner, self()) of
                            true ->
                                Pub = [named_table, public],
                                _ = ets:new(?ENDPOINTS, [ordered_set | Pub]),
                                _ = ets:new(?SESSIONS, [set | Pub]),
                                _ = ets:new(?STATE, [set | Pub]),
                                _ = case pg:start(?SCOPE) of
                                        {ok, _} -> ok;
                                        {error, {already_started, _}} -> ok
                                    end,
                                Caller ! {rakun_websocket_owner, ready},
                                receive stop -> ok end;
                            _ ->
                                Caller ! {rakun_websocket_owner, ready}
                        end
                end),
    Ref = erlang:monitor(process, Pid),
    receive
        {rakun_websocket_owner, ready} -> erlang:demonitor(Ref, [flush]), ok;
        {'DOWN', Ref, process, Pid, _} -> ok
    after 5000 -> erlang:demonitor(Ref, [flush]), ok
    end.
