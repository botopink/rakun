%%% rakun-messaging — the STOMP 1.2 arm of front 90: the frame codec and a
%%% client over gen_tcp / ssl. The AMQP 1.0 arm would bind `amqp10_client`,
%%% an OTP application a sidecar cannot load (the toolchain row), so it is
%%% refused at boot instead of written.
%%%
%%% CODEC: `COMMAND\n` + `name:value\n`… + `\n` + body + NUL. Header names and
%%% values escape `\\`, `\r`, `\n` and `:` (STOMP 1.2 §Value Encoding; CONNECT
%%% and CONNECTED are not escaped). A frame with `content-length` is read by
%%% length, otherwise to the NUL. A body that is not valid UTF-8 is refused.
%%%
%%% CLIENT: one connection process per `connect/5`: CONNECT, CONNECTED, the
%%% heart-beat negotiated as max(ours, theirs) per direction (0 = off); a
%%% missed incoming beat closes the connection. Subscriptions call a handler
%%% (`fun(Body, Headers) -> ack | nack`) in the connection process and ACK /
%%% NACK when the subscription is `client-individual`. A dropped connection
%%% is re-dialled with backoff and every subscription re-declared.

-module(rakun_jms).
-compile(nowarn_deprecated_catch).
-export([encode/3, decode/1, escape/1, unescape/1, connect/6, send/4, subscribe/6, unsubscribe/2,
         close/1, alive/1, reconnects/1, request/5]).

%% ═══ the codec ═══════════════════════════════════════════════════════════════

escape(V) ->
    lists:foldl(fun({F, T}, Acc) -> binary:replace(Acc, F, T, [global]) end, V,
                [{<<"\\">>, <<"\\\\">>}, {<<"\r">>, <<"\\r">>}, {<<"\n">>, <<"\\n">>}, {<<":">>, <<"\\c">>}]).

unescape(V) -> unescape(V, <<>>).
unescape(<<"\\\\", R/binary>>, A) -> unescape(R, <<A/binary, "\\">>);
unescape(<<"\\r", R/binary>>, A) -> unescape(R, <<A/binary, "\r">>);
unescape(<<"\\n", R/binary>>, A) -> unescape(R, <<A/binary, "\n">>);
unescape(<<"\\c", R/binary>>, A) -> unescape(R, <<A/binary, ":">>);
unescape(<<C, R/binary>>, A) -> unescape(R, <<A/binary, C>>);
unescape(<<>>, A) -> A.

raw(Cmd) -> Cmd =:= <<"CONNECT">> orelse Cmd =:= <<"CONNECTED">>.

encode(Cmd, Headers, Body) ->
    case unicode:characters_to_binary(Body) of
        B when is_binary(B) -> ok;
        _ -> erlang:error({panic, <<"rakun jms: a STOMP body must be text - the milestone has no byte type (language-gaps: No byte or binary type), so a BytesMessage cannot cross this arm">>})
    end,
    E = case raw(Cmd) of true -> fun(X) -> X end; false -> fun escape/1 end,
    HasLen = lists:keymember(<<"content-length">>, 1, Headers),
    Hs = Headers ++ [{<<"content-length">>, integer_to_binary(byte_size(Body))} || not HasLen, Body =/= <<>>],
    iolist_to_binary([Cmd, "\n", [[E(K), ":", E(V), "\n"] || {K, V} <- Hs], "\n", Body, 0]).

%% {ok, {Cmd, Headers, Body}, Rest} | more
decode(Bin0) ->
    Bin = skip_eols(Bin0),
    case binary:split(Bin, <<"\n\n">>) of
        [_] -> more;
        [Head, Tail] ->
            [Cmd | HLines] = binary:split(binary:replace(Head, <<"\r\n">>, <<"\n">>, [global]), <<"\n">>, [global]),
            U = case raw(Cmd) of true -> fun(X) -> X end; false -> fun unescape/1 end,
            Headers = [begin [K, V] = binary:split(L, <<":">>), {U(K), U(V)} end || L <- HLines, L =/= <<>>],
            case lists:keyfind(<<"content-length">>, 1, Headers) of
                {_, LenB} ->
                    Len = binary_to_integer(LenB),
                    case Tail of
                        <<Body:Len/binary, 0, Rest/binary>> -> {ok, {Cmd, Headers, Body}, Rest};
                        _ -> more
                    end;
                false ->
                    case binary:split(Tail, <<0>>) of
                        [Body, Rest] -> {ok, {Cmd, Headers, Body}, Rest};
                        [_] -> more
                    end
            end
    end.

skip_eols(<<"\n", R/binary>>) -> skip_eols(R);
skip_eols(<<"\r\n", R/binary>>) -> skip_eols(R);
skip_eols(B) -> B.

%% ═══ the client ══════════════════════════════════════════════════════════════
%% Opts: [{heart_beat, {Cx, Cy}}, {tls, SslOpts}, {client_id, Id}]

connect(Host, Port, User, Pass, HeartMs, TlsOpts) ->
    Me = self(),
    Pid = spawn(fun() -> conn_init(Me, #{host => Host, port => Port, user => User, pass => Pass, beat => HeartMs, tls => TlsOpts, subs => #{}, reconnects => 0, waiters => #{}}) end),
    receive
        {rakun_jms_up, Pid} -> {ok, Pid};
        {rakun_jms_failed, Pid, Why} -> {error, Why}
    after 5000 -> exit(Pid, kill), {error, <<"the STOMP broker did not answer CONNECT">>}
    end.

dial(#{host := H, port := P, tls := Tls}) ->
    case Tls of
        [] -> case gen_tcp:connect(binary_to_list(H), P, [binary, {active, true}], 3000) of
                  {ok, S} -> {ok, {gen_tcp, S}};
                  E -> E
              end;
        Opts -> _ = application:ensure_all_started(ssl),
                case ssl:connect(binary_to_list(H), P, [binary, {active, true} | Opts], 3000) of
                    {ok, S} -> {ok, {ssl, S}};
                    E -> E
                end
    end.

handshake(St = #{user := U, pass := Pw, beat := B, host := H}) ->
    case dial(St) of
        {ok, {M, S} = C} ->
            Hs = [{<<"accept-version">>, <<"1.2">>}, {<<"host">>, H}, {<<"heart-beat">>, iolist_to_binary([integer_to_binary(B), ",", integer_to_binary(B)])}]
                ++ [{<<"login">>, U} || U =/= <<>>] ++ [{<<"passcode">>, Pw} || Pw =/= <<>>],
            ok = M:send(S, encode(<<"CONNECT">>, Hs, <<>>)),
            case await_frame(C, <<>>, 3000) of
                {{<<"CONNECTED">>, RH, _}, Rest} ->
                    {Sx, Sy} = case lists:keyfind(<<"heart-beat">>, 1, RH) of
                                   {_, V} -> [A, Bb] = binary:split(V, <<",">>), {binary_to_integer(A), binary_to_integer(Bb)};
                                   false -> {0, 0}
                               end,
                    Out = case B =:= 0 orelse Sy =:= 0 of true -> 0; false -> max(B, Sy) end,
                    In = case B =:= 0 orelse Sx =:= 0 of true -> 0; false -> max(B, Sx) end,
                    {ok, St#{conn => C, buf => Rest, out => Out, in => In, last_in => now_ms()}};
                {{<<"ERROR">>, RH, Body}, _} -> {error, iolist_to_binary(["the broker refused CONNECT: ", proplists:get_value(<<"message">>, RH, <<>>), " ", Body])};
                _ -> {error, <<"no CONNECTED frame">>}
            end;
        {error, R} -> {error, iolist_to_binary(io_lib:format("~p", [R]))}
    end.

await_frame(C = {_, S}, Buf, T) ->
    case decode(Buf) of
        {ok, F, Rest} -> {F, Rest};
        more -> receive {_, S, Data} when is_binary(Data) -> await_frame(C, <<Buf/binary, Data/binary>>, T)
                after T -> timeout end
    end.

now_ms() -> erlang:monotonic_time(millisecond).

conn_init(Parent, St0) ->
    case handshake(St0) of
        {ok, St} -> Parent ! {rakun_jms_up, self()}, schedule(St), loop(St);
        {error, Why} -> Parent ! {rakun_jms_failed, self(), Why}
    end.

schedule(#{out := Out, in := In}) ->
    [erlang:send_after(Out, self(), beat) || Out > 0],
    [erlang:send_after(In, self(), check_in) || In > 0],
    ok.

write(#{conn := {M, S}}, Bin) -> M:send(S, Bin).

loop(St = #{conn := {_, S}, buf := Buf}) ->
    receive
        {Tag, S, Data} when Tag =:= tcp; Tag =:= ssl ->
            frames(St#{buf := <<Buf/binary, Data/binary>>, last_in := now_ms()});
        {Tag, S} when Tag =:= tcp_closed; Tag =:= ssl_closed -> redial(St);
        beat -> _ = write(St, <<"\n">>), erlang:send_after(maps:get(out, St), self(), beat), loop(St);
        check_in ->
            case now_ms() - maps:get(last_in, St) > 2 * maps:get(in, St) of
                true -> close_conn(St), exit(normal);
                false -> erlang:send_after(maps:get(in, St), self(), check_in), loop(St)
            end;
        {send, From, Ref, Dest, Body, Headers} ->
            R = <<"r", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
            _ = write(St, encode(<<"SEND">>, [{<<"destination">>, Dest}, {<<"receipt">>, R} | Headers], Body)),
            loop(St#{waiters := maps:put(R, {From, Ref}, maps:get(waiters, St))});
        {subscribe, From, Ref, Id, Headers, Handler} ->
            R = <<"s", Id/binary>>,
            _ = write(St, encode(<<"SUBSCRIBE">>, [{<<"id">>, Id}, {<<"receipt">>, R} | Headers], <<>>)),
            loop(St#{subs := maps:put(Id, {Headers, Handler}, maps:get(subs, St)), waiters := maps:put(R, {From, Ref}, maps:get(waiters, St))});
        {unsubscribe, Id} ->
            _ = write(St, encode(<<"UNSUBSCRIBE">>, [{<<"id">>, Id}], <<>>)),
            loop(St#{subs := maps:remove(Id, maps:get(subs, St))});
        {verdict, <<"auto">>, _, _} -> loop(St);
        {verdict, _, AckId, V} ->
            Cmd = case V of ack -> <<"ACK">>; _ -> <<"NACK">> end,
            _ = write(St, encode(Cmd, [{<<"id">>, AckId}], <<>>)),
            loop(St);
        {alive, From} -> From ! {rakun_jms_alive, true}, loop(St);
        {reconnects, From} -> From ! {rakun_jms_reconnects, maps:get(reconnects, St)}, loop(St);
        close -> _ = write(St, encode(<<"DISCONNECT">>, [], <<>>)), close_conn(St), ok
    end.

frames(St = #{buf := Buf}) ->
    case decode(Buf) of
        more -> loop(St);
        {ok, {<<"RECEIPT">>, H, _}, Rest} ->
            R = proplists:get_value(<<"receipt-id">>, H),
            W = maps:get(waiters, St),
            case maps:take(R, W) of
                {{From, Ref}, W2} -> From ! {Ref, ok}, frames(St#{buf := Rest, waiters := W2});
                error -> frames(St#{buf := Rest})
            end;
        {ok, {<<"ERROR">>, H, Body}, Rest} ->
            Msg = iolist_to_binary([proplists:get_value(<<"message">>, H, <<>>), " ", Body]),
            [From ! {Ref, {error, Msg}} || {From, Ref} <- maps:values(maps:get(waiters, St))],
            frames(St#{buf := Rest, waiters := #{}});
        {ok, {<<"MESSAGE">>, H, Body}, Rest} ->
            Id = proplists:get_value(<<"subscription">>, H),
            case maps:find(Id, maps:get(subs, St)) of
                {ok, {SubHs, Handler}} ->
                    %% the handler runs in its own process: it may send on
                    %% this connection, which answers it from this loop
                    Me = self(),
                    AckId = proplists:get_value(<<"ack">>, H, proplists:get_value(<<"message-id">>, H)),
                    Mode = proplists:get_value(<<"ack">>, SubHs, <<"auto">>),
                    spawn(fun() -> V = try Handler(Body, H) catch _:_ -> nack end, Me ! {verdict, Mode, AckId, V} end);
                error -> ok
            end,
            frames(St#{buf := Rest});
        {ok, _, Rest} -> frames(St#{buf := Rest})
    end.

close_conn(#{conn := {M, S}}) -> catch M:close(S).

redial(St = #{reconnects := N}) ->
    timer:sleep(min(2000, 50 * (1 bsl min(N, 5)))),
    case handshake(St) of
        {ok, St2} ->
            [write(St2, encode(<<"SUBSCRIBE">>, [{<<"id">>, Id} | Hs], <<>>)) || {Id, {Hs, _}} <- maps:to_list(maps:get(subs, St2))],
            schedule(St2),
            loop(St2#{reconnects := N + 1});
        {error, _} -> redial(St#{reconnects := N + 1})
    end.

call(Pid, Msg, T) ->
    Ref = make_ref(),
    MRef = erlang:monitor(process, Pid),
    Pid ! setelement(3, setelement(2, Msg, self()), Ref),
    receive
        {Ref, R} -> erlang:demonitor(MRef, [flush]), R;
        {'DOWN', MRef, _, _, _} -> {error, <<"the STOMP connection closed">>}
    after T -> erlang:demonitor(MRef, [flush]), {error, <<"no receipt from the broker">>}
    end.

send(Pid, Dest, Body, Headers) ->
    _ = encode(<<"SEND">>, [], Body),
    call(Pid, {send, x, x, Dest, Body, Headers}, 5000).

subscribe(Pid, Id, Dest, Ack, Extra, Handler) ->
    call(Pid, {subscribe, x, x, Id, [{<<"destination">>, Dest}, {<<"ack">>, Ack} | Extra], Handler}, 5000).

unsubscribe(Pid, Id) -> Pid ! {unsubscribe, Id}, ok.
close(Pid) -> Pid ! close, ok.
alive(Pid) -> is_process_alive(Pid).
reconnects(Pid) -> Pid ! {reconnects, self()}, receive {rakun_jms_reconnects, N} -> N after 2000 -> -1 end.

%% Request/reply: a temporary queue per request, `reply-to` and
%% `correlation-id`; the reply is a receive on the correlation id.
request(Pid, Dest, Body, TimeoutMs, Corr) ->
    Me = self(),
    Temp = <<"/temp-queue/rakun-", Corr/binary>>,
    SubId = <<"reply-", Corr/binary>>,
    Handler = fun(B, H) -> Me ! {rakun_jms_reply, proplists:get_value(<<"correlation-id">>, H), B}, ack end,
    try
        ok = subscribe(Pid, SubId, Temp, <<"auto">>, [], Handler),
        ok = send(Pid, Dest, Body, [{<<"reply-to">>, Temp}, {<<"correlation-id">>, Corr}]),
        receive {rakun_jms_reply, Corr, Reply} -> {ok, Reply}
        after TimeoutMs -> {error, iolist_to_binary(["no reply to ", Corr, " within ", integer_to_binary(TimeoutMs), " ms"])}
        end
    after
        unsubscribe(Pid, SubId)
    end.
