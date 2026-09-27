%%% rakun-messaging — a STOMP 1.2 broker for front 90's tests (the shape of
%%% ActiveMQ's STOMP transport, in-process). `/queue/<n>`: each message to ONE
%%% subscriber, round robin, held until one exists; `/topic/<n>`: a copy per
%%% subscription, and a DURABLE subscription (`activemq.subscriptionName` with
%%% the connection's `client-id`) keeps accumulating while its client is gone;
%%% `/temp-queue/<n>` is a queue removed with its last subscription. A
%%% `selector` header of the form `name = 'value'` filters at the broker;
%%% anything else answers ERROR. `client-individual` subscriptions are
%%% redelivered on NACK. Heart-beats are answered; `silent-after=<n>` stops
%%% the broker's beats after n.
%%% Opts: [<<"heart=<ms>">>, <<"reject-login">>].

-module(rakun_jms_fixture).
-compile(nowarn_deprecated_catch).
-export([start/1, stop/1, delivered/2, frames/1, drop_all/1]).

start(Opts) ->
    Me = self(),
    Pid = spawn(fun() -> init(Me, Opts) end),
    receive {rakun_jms_fixture, Port} -> persistent_term:put({rakun_jms_fixture, Port}, Pid), Port after 3000 -> 0 end.

stop(Port) ->
    case persistent_term:get({rakun_jms_fixture, Port}, undefined) of
        undefined -> 0;
        Pid -> Pid ! stop, persistent_term:erase({rakun_jms_fixture, Port}), 0
    end.

%% Closes every client socket (the broker restarts; state is kept).
drop_all(Port) -> persistent_term:get({rakun_jms_fixture, Port}) ! drop_all, 0.

opt(Opts, K) -> case [binary:part(O, byte_size(K) + 1, byte_size(O) - byte_size(K) - 1) || O <- Opts, binary:match(O, <<K/binary, "=">>) =:= {0, byte_size(K) + 1}] of [V | _] -> V; [] -> <<>> end.

init(Parent, Opts) ->
    {ok, L} = gen_tcp:listen(0, [binary, {active, false}, {reuseaddr, true}]),
    {ok, Port} = inet:port(L),
    Broker = self(),
    spawn_link(fun() -> accept(L, Broker, Opts) end),
    Parent ! {rakun_jms_fixture, Port},
    broker(#{port => Port, subs => [], pending => #{}, durable => #{}, log => [], rr => 0, conns => [], seq => 0}).

accept(L, Broker, Opts) ->
    case gen_tcp:accept(L) of
        {ok, S} ->
            P = spawn(fun() -> receive go -> session(S, Broker, Opts, <<>>, #{}) end end),
            ok = gen_tcp:controlling_process(S, P),
            Broker ! {conn, P},
            P ! go,
            accept(L, Broker, Opts);
        _ -> ok
    end.

session(S, Broker, Opts, Buf, Me) ->
    ok = inet:setopts(S, [{active, once}]),
    receive
        {tcp, S, Data} -> handle(S, Broker, Opts, <<Buf/binary, Data/binary>>, Me);
        {tcp_closed, S} -> Broker ! {gone, self()};
        {out, Frame} -> gen_tcp:send(S, Frame), session(S, Broker, Opts, Buf, Me);
        drop -> gen_tcp:close(S), Broker ! {gone, self()};
        beat -> gen_tcp:send(S, <<"\n">>), erlang:send_after(maps:get(heart, Me, 1000), self(), beat), session(S, Broker, Opts, Buf, Me)
    end.

handle(S, Broker, Opts, Buf, Me) ->
    case rakun_jms:decode(Buf) of
        more -> session(S, Broker, Opts, Buf, Me);
        {ok, {Cmd, H, Body}, Rest} ->
            Broker ! {frame, Cmd},
            Me2 = command(S, Broker, Opts, Cmd, H, Body, Me),
            handle(S, Broker, Opts, Rest, Me2)
    end.

say(S, Cmd, H, B) -> gen_tcp:send(S, rakun_jms:encode(Cmd, H, B)).

receipt(S, H) ->
    case lists:keyfind(<<"receipt">>, 1, H) of
        {_, R} -> say(S, <<"RECEIPT">>, [{<<"receipt-id">>, R}], <<>>);
        false -> ok
    end.

command(S, _Broker, Opts, <<"CONNECT">>, H, _, Me) ->
    case lists:member(<<"reject-login">>, Opts) of
        true -> say(S, <<"ERROR">>, [{<<"message">>, <<"bad credentials">>}], <<>>), Me;
        false ->
            Beat = case opt(Opts, <<"heart">>) of <<>> -> <<"0,0">>; V -> <<V/binary, ",", V/binary>> end,
            say(S, <<"CONNECTED">>, [{<<"version">>, <<"1.2">>}, {<<"heart-beat">>, Beat}], <<>>),
            case opt(Opts, <<"heart">>) of <<>> -> ok; V2 -> erlang:send_after(binary_to_integer(V2), self(), beat) end,
            Me#{client => proplists:get_value(<<"client-id">>, H, <<>>), heart => case opt(Opts, <<"heart">>) of <<>> -> 1000; V3 -> binary_to_integer(V3) end}
    end;
command(S, Broker, _, <<"SEND">>, H, Body, Me) ->
    Broker ! {send, proplists:get_value(<<"destination">>, H), Body, H},
    receipt(S, H), Me;
command(S, Broker, _, <<"SUBSCRIBE">>, H, _, Me) ->
    Sel = proplists:get_value(<<"selector">>, H, <<>>),
    case selector(Sel) of
        bad -> say(S, <<"ERROR">>, [{<<"message">>, <<"unsupported selector">>}], Sel), Me;
        Parsed ->
            Broker ! {subscribe, self(), proplists:get_value(<<"id">>, H), proplists:get_value(<<"destination">>, H),
                      proplists:get_value(<<"ack">>, H, <<"auto">>), Parsed, proplists:get_value(<<"activemq.subscriptionName">>, H, <<>>), maps:get(client, Me, <<>>)},
            receipt(S, H), Me
    end;
command(S, Broker, _, <<"UNSUBSCRIBE">>, H, _, Me) ->
    Broker ! {unsubscribe, self(), proplists:get_value(<<"id">>, H)}, receipt(S, H), Me;
command(S, Broker, _, Cmd, H, _, Me) when Cmd =:= <<"ACK">>; Cmd =:= <<"NACK">> ->
    Broker ! {settle, Cmd, proplists:get_value(<<"id">>, H)}, receipt(S, H), Me;
command(S, _, _, <<"DISCONNECT">>, H, _, Me) -> receipt(S, H), Me;
command(_, _, _, _, _, _, Me) -> Me.

%% `name = 'value'` only.
selector(<<>>) -> any;
selector(Sel) ->
    case re:run(Sel, "^\\s*([A-Za-z_][A-Za-z0-9_-]*)\\s*=\\s*'([^']*)'\\s*$", [{capture, all_but_first, binary}]) of
        {match, [K, V]} -> {eq, K, V};
        _ -> bad
    end.

matches(any, _) -> true;
matches({eq, K, V}, H) -> proplists:get_value(K, H) =:= V.

kind(<<"/topic/", _/binary>>) -> topic;
kind(_) -> queue.

broker(B) ->
    receive
        stop -> [P ! drop || P <- maps:get(conns, B)], ok;
        drop_all -> [P ! drop || P <- maps:get(conns, B)], broker(B#{conns := []});
        {conn, P} -> erlang:monitor(process, P), broker(B#{conns := [P | maps:get(conns, B)]});
        {frame, Cmd} -> broker(B#{log := [Cmd | maps:get(log, B)]});
        {gone, P} -> broker(detach(P, B));
        {'DOWN', _, process, P, _} -> broker(detach(P, B));
        {subscribe, P, Id, Dest, Ack, Sel, Durable, Client} ->
            Sub = #{pid => P, id => Id, dest => Dest, ack => Ack, sel => Sel, durable => {Client, Durable}},
            B2 = B#{subs := maps:get(subs, B) ++ [Sub]},
            B3 = case {Durable, Client} of
                     {<<>>, _} -> B2;
                     _ -> Kept = maps:get({Client, Durable}, maps:get(durable, B2), []),
                          [deliver_to(Sub, M, H, B2) || {M, H} <- Kept],
                          B2#{durable := maps:remove({Client, Durable}, maps:get(durable, B2))}
                 end,
            broker(flush_queue(Dest, B3));
        {unsubscribe, P, Id} ->
            broker(B#{subs := [X || X = #{pid := Q, id := I} <- maps:get(subs, B), not (Q =:= P andalso I =:= Id)]});
        {send, Dest, Body, H} ->
            broker(route(Dest, Body, H, B));
        {settle, <<"NACK">>, AckId} ->
            {Dest, Body, H} = binary_to_term(base64:decode(AckId)),
            broker(route(Dest, Body, H, B));
        {settle, _, _} -> broker(B);
        {delivered, From, Dest} ->
            From ! {rakun_jms_delivered, length([x || {D, _} <- maps:get(log_msgs, B, []), D =:= Dest])}, broker(B);
        {frames, From} -> From ! {rakun_jms_frames, lists:reverse(maps:get(log, B))}, broker(B)
    end.

detach(P, B) ->
    Durables = [{K, S} || S = #{pid := Q, durable := K} <- maps:get(subs, B), Q =:= P, element(2, K) =/= <<>>],
    B2 = B#{subs := [S || S = #{pid := Q} <- maps:get(subs, B), Q =/= P], conns := lists:delete(P, maps:get(conns, B))},
    lists:foldl(fun({K, S}, Acc) -> Acc#{durable := maps:put(K, maps:get(K, maps:get(durable, Acc), []), maps:get(durable, Acc)), away => maps:put(K, S, maps:get(away, Acc, #{}))} end, B2, Durables).

route(Dest, Body, H, B) ->
    Subs = [S || S = #{dest := D} <- maps:get(subs, B), D =:= Dest],
    B1 = B#{log_msgs => [{Dest, Body} | maps:get(log_msgs, B, [])]},
    case kind(Dest) of
        topic ->
            [deliver_to(S, Body, H, B1) || S <- Subs, matches(maps:get(sel, S), H)],
            Away = [K || {K, #{dest := D}} <- maps:to_list(maps:get(away, B1, #{})), D =:= Dest],
            lists:foldl(fun(K, Acc) -> Acc#{durable := maps:put(K, maps:get(K, maps:get(durable, Acc), []) ++ [{Body, H}], maps:get(durable, Acc))} end, B1, Away);
        queue ->
            case [S || S <- Subs, matches(maps:get(sel, S), H)] of
                [] -> B1#{pending := maps:put(Dest, maps:get(Dest, maps:get(pending, B1), []) ++ [{Body, H}], maps:get(pending, B1))};
                Ms ->
                    N = maps:get(rr, B1),
                    deliver_to(lists:nth(1 + N rem length(Ms), Ms), Body, H, B1),
                    B1#{rr := N + 1}
            end
    end.

flush_queue(Dest, B) ->
    case kind(Dest) of
        queue ->
            Pending = maps:get(Dest, maps:get(pending, B), []),
            lists:foldl(fun({Body, H}, Acc) -> route(Dest, Body, H, Acc) end, B#{pending := maps:remove(Dest, maps:get(pending, B))}, Pending);
        topic -> B
    end.

deliver_to(#{pid := P, id := Id, dest := Dest}, Body, H, _B) ->
    Seq = erlang:unique_integer([positive]),
    Extra = [X || X = {K, _} <- H, lists:member(K, [<<"correlation-id">>, <<"reply-to">>]) orelse binary:match(K, <<"x-">>) =:= {0, 2} orelse K =:= <<"type">>],
    P ! {out, rakun_jms:encode(<<"MESSAGE">>, [{<<"subscription">>, Id}, {<<"message-id">>, integer_to_binary(Seq)}, {<<"destination">>, Dest}, {<<"ack">>, term_to_ack(Dest, Body, H)} | Extra], Body)}.

term_to_ack(Dest, Body, H) ->
    K = base64:encode(term_to_binary({Dest, Body, H})),
    K.

delivered(Port, Dest) ->
    persistent_term:get({rakun_jms_fixture, Port}) ! {delivered, self(), Dest},
    receive {rakun_jms_delivered, N} -> N after 2000 -> -1 end.

frames(Port) ->
    persistent_term:get({rakun_jms_fixture, Port}) ! {frames, self()},
    receive {rakun_jms_frames, L} -> L after 2000 -> [] end.
