%%% rakun-rsocket — RSocket 1.0 over TCP (front 92): the frame codec, the
%%% responder (one connection process, one process per stream) and the
%%% requester. Botopink has no byte type, so the wire is here.
%%%
%%% FRAMES on TCP: [length:24][stream:32 (top bit 0)][type:6|flags:10] …; a
%%% frame with M carries [metadata length:24][metadata] before its data.
%%% Twelve types are spoken; RESUME in a SETUP (flag R) is answered with
%%% ERROR UNSUPPORTED_SETUP naming resumption. ROUTING is composite metadata:
%%% the well-known `message/x.rsocket.routing.v0` (0x7E) entry holding
%%% length-prefixed tags; a request without it is an ERROR naming the missing
%%% route.
%%%
%%% RESPONDER: `serve/3` binds its own port. Handlers by route:
%%%   {fnf, F}      F(Data) -> done | {reject, R} | {retry, R}; nothing is sent
%%%   {rr, F}       F(Data) -> Binary; one PAYLOAD (N|C), or ERROR on a raise
%%%   {stream, F}   F(Data) -> [Item]; emitted only against REQUEST_N credit,
%%%                 COMPLETE after the last; CANCEL stops the producer
%%% `OnReject(Route, Data, Reason)` is called for a fire-and-forget Reject
%%% (front 86's dead letter). A missed keep-alive past the negotiated max
%%% lifetime closes the connection; closing kills every stream process.
%%% With `lease` configured the responder sends LEASE after SETUP.
%%%
%%% REQUESTER: `connect/4` sends SETUP (and keep-alives); `request_response`,
%%% `fire_and_forget` (returns once written), `request_stream` / `request_n`
%%% / `next` / `cancel`. Under a LEASE the requester rejects a request past
%%% the budget locally, writing nothing.

-module(rakun_rsocket).
-compile(nowarn_deprecated_catch).
-export([encode/1, decode/2, route_metadata/1, route_of/1,
         serve/4, stop/1, stream_procs/1,
         connect/4, close/1, request_response/4, fire_and_forget/3, request_stream/4, request_n/2, next/2, cancel/1,
         written/1]).

-define(SETUP, 16#01). -define(LEASE, 16#02). -define(KEEPALIVE, 16#03). -define(RR, 16#04).
-define(FNF, 16#05). -define(STREAM, 16#06). -define(CHANNEL, 16#07). -define(REQN, 16#08).
-define(CANCEL, 16#09). -define(PAYLOAD, 16#0A). -define(ERROR, 16#0B). -define(MPUSH, 16#0C).
-define(M, 16#100). -define(F_R, 16#80). -define(F_C, 16#40). -define(F_N, 16#20).

%% ═══ the codec ═══════════════════════════════════════════════════════════════
%% A frame is a map: #{type, stream, flags, meta, data, n, code, interval, lifetime, ttl, count, position}.

payload(F) ->
    Data = maps:get(data, F, <<>>),
    case maps:get(meta, F, undefined) of
        undefined -> {0, Data};
        Meta -> {?M, <<(byte_size(Meta)):24, Meta/binary, Data/binary>>}
    end.

encode(F) ->
    T = maps:get(type, F), S = maps:get(stream, F, 0), Fl0 = maps:get(flags, F, 0),
    {Mf, Pl} = payload(F),
    Body = case T of
               ?SETUP -> <<1:16, 0:16, (maps:get(interval, F, 20000)):32, (maps:get(lifetime, F, 90000)):32,
                           (case maps:get(resume_token, F, undefined) of undefined -> <<>>; Tok -> <<(byte_size(Tok)):16, Tok/binary>> end)/binary,
                           (mime(maps:get(meta_mime, F, <<"message/x.rsocket.composite-metadata.v0">>)))/binary,
                           (mime(maps:get(data_mime, F, <<"text/plain">>)))/binary, Pl/binary>>;
               ?LEASE -> <<(maps:get(ttl, F)):32, (maps:get(count, F)):32, (maps:get(meta, F, <<>>))/binary>>;
               ?KEEPALIVE -> <<(maps:get(position, F, 0)):64, (maps:get(data, F, <<>>))/binary>>;
               ?REQN -> <<(maps:get(n, F)):32>>;
               ?CANCEL -> <<>>;
               ?ERROR -> <<(maps:get(code, F)):32, (maps:get(data, F, <<>>))/binary>>;
               T2 when T2 =:= ?STREAM; T2 =:= ?CHANNEL -> <<(maps:get(n, F)):32, Pl/binary>>;
               ?MPUSH -> maps:get(meta, F, <<>>);
               _ -> Pl
           end,
    Fl1 = case {T, maps:is_key(resume_token, F)} of {?SETUP, true} -> Fl0 bor ?F_R; _ -> Fl0 end,
    Flags = case T of ?LEASE -> Fl0; ?KEEPALIVE -> Fl0; ?REQN -> Fl0; ?CANCEL -> Fl0; ?ERROR -> Fl0; ?MPUSH -> Fl0 bor ?M; _ -> Fl1 bor Mf end,
    Frame = <<0:1, S:31, T:6, Flags:10, Body/binary>>,
    <<(byte_size(Frame)):24, Frame/binary>>.

mime(M) -> <<(byte_size(M)):8, M/binary>>.

%% {ok, Frame, Rest} | more | {error, Reason}
decode(Bin, Max) ->
    case Bin of
        <<Len:24, _/binary>> when Len > Max -> {error, iolist_to_binary(["the frame of ", integer_to_binary(Len), " bytes exceeds the maximum of ", integer_to_binary(Max)])};
        <<Len:24, Frame:Len/binary, Rest/binary>> -> {ok, frame(Frame), Rest};
        _ -> more
    end.

frame(<<0:1, S:31, T:6, Flags:10, Body/binary>>) ->
    Base = #{type => T, stream => S, flags => Flags},
    case T of
        ?SETUP ->
            <<_:32, Interval:32, Lifetime:32, R1/binary>> = Body,
            R2 = case Flags band ?F_R of 0 -> R1; _ -> <<TL:16, _:TL/binary, X/binary>> = R1, X end,
            <<ML:8, MM:ML/binary, DL:8, DM:DL/binary, P/binary>> = R2,
            maps:merge(Base#{interval => Interval, lifetime => Lifetime, meta_mime => MM, data_mime => DM, resume => (Flags band ?F_R) =/= 0}, split(Flags, P));
        ?LEASE -> <<Ttl:32, Count:32, Meta/binary>> = Body, Base#{ttl => Ttl, count => Count, meta => Meta};
        ?KEEPALIVE -> <<Pos:64, Data/binary>> = Body, Base#{position => Pos, data => Data};
        ?REQN -> <<N:32>> = Body, Base#{n => N};
        ?CANCEL -> Base;
        ?ERROR -> <<Code:32, Data/binary>> = Body, Base#{code => Code, data => Data};
        T2 when T2 =:= ?STREAM; T2 =:= ?CHANNEL -> <<N:32, P/binary>> = Body, maps:merge(Base#{n => N}, split(Flags, P));
        ?MPUSH -> Base#{meta => Body};
        _ -> maps:merge(Base, split(Flags, Body))
    end.

split(Flags, P) ->
    case Flags band ?M of
        0 -> #{data => P};
        _ -> <<ML:24, Meta:ML/binary, Data/binary>> = P, #{meta => Meta, data => Data}
    end.

%% Composite metadata holding one routing entry with `Route` as its tag.
route_metadata(Route) ->
    Tag = <<(byte_size(Route)):8, Route/binary>>,
    <<(16#80 bor 16#7E):8, (byte_size(Tag)):24, Tag/binary>>.

route_of(undefined) -> none;
route_of(<<>>) -> none;
route_of(<<Id:8, Len:24, Entry:Len/binary, Rest/binary>>) when Id =:= (16#80 bor 16#7E) ->
    <<TL:8, Tag:TL/binary, _/binary>> = Entry, _ = Rest, Tag;
route_of(<<Id:8, Len:24, _:Len/binary, Rest/binary>>) when Id >= 16#80 -> route_of(Rest);
route_of(<<ML:8, _:ML/binary, Len:24, _:Len/binary, Rest/binary>>) -> route_of(Rest);
route_of(_) -> none.

%% ═══ the responder ═══════════════════════════════════════════════════════════

serve(Port, Handlers, OnReject, Opts) ->
    Me = self(),
    Pid = spawn(fun() ->
                        {ok, L} = gen_tcp:listen(Port, [binary, {active, false}, {reuseaddr, true}]),
                        {ok, P} = inet:port(L),
                        Me ! {rakun_rsocket_port, P},
                        accept(L, Handlers, OnReject, Opts)
                end),
    receive {rakun_rsocket_port, P} -> persistent_term:put({rakun_rsocket_server, P}, Pid), P after 3000 -> 0 end.

stop(Port) ->
    case persistent_term:get({rakun_rsocket_server, Port}, undefined) of
        undefined -> 0;
        Pid -> exit(Pid, kill), persistent_term:erase({rakun_rsocket_server, Port}), 1
    end.

accept(L, H, OnReject, Opts) ->
    case gen_tcp:accept(L) of
        {ok, S} ->
            P = spawn(fun() -> receive go -> responder(S, H, OnReject, Opts) end end),
            ok = gen_tcp:controlling_process(S, P),
            P ! go,
            accept(L, H, OnReject, Opts);
        _ -> ok
    end.

send_frame(S, F) -> gen_tcp:send(S, encode(F)).

responder(S, H, OnReject, Opts) ->
    process_flag(trap_exit, true),
    inet:setopts(S, [{active, true}]),
    persistent_term:put(rakun_rsocket_last_responder, self()),
    rloop(#{sock => S, handlers => H, reject => OnReject, opts => Opts, buf => <<>>, streams => #{}, setup => false,
            lifetime => 90000, last => now_ms()}).

now_ms() -> erlang:monotonic_time(millisecond).

rloop(St = #{sock := S, buf := Buf}) ->
    receive
        {tcp, S, Data} -> rframes(St#{buf := <<Buf/binary, Data/binary>>, last := now_ms()});
        {tcp_closed, S} -> shutdown(St);
        check_life ->
            case now_ms() - maps:get(last, St) > maps:get(lifetime, St) of
                true -> gen_tcp:close(S), shutdown(St);
                false -> erlang:send_after(maps:get(lifetime, St) div 2 + 1, self(), check_life), rloop(St)
            end;
        {emit, F} -> send_frame(S, F), rloop(St);
        {'EXIT', _, _} -> rloop(St);
        {streams, From} -> From ! {rakun_rsocket_streams, [P || P <- maps:values(maps:get(streams, St)), is_process_alive(P)]}, rloop(St)
    end.

shutdown(#{streams := Ss}) -> [exit(P, kill) || P <- maps:values(Ss)], ok.

rframes(St = #{buf := Buf, opts := Opts}) ->
    case decode(Buf, proplists:get_value(max_frame, Opts, 16777215)) of
        more -> rloop(St);
        {error, R} -> send_frame(maps:get(sock, St), #{type => ?ERROR, stream => 0, code => 16#101, data => R}), gen_tcp:close(maps:get(sock, St)), shutdown(St);
        {ok, F, Rest} -> rframes(handle(F, St#{buf := Rest}))
    end.

handle(#{type := ?SETUP} = F, St = #{sock := S, opts := Opts}) ->
    case maps:get(resume, F) of
        true ->
            send_frame(S, #{type => ?ERROR, stream => 0, code => 16#2, data => <<"resumption (RESUME / RESUME_OK) is not supported by this responder">>}),
            St;
        false ->
            erlang:send_after(maps:get(lifetime, F) div 2 + 1, self(), check_life),
            case proplists:get_value(lease, Opts) of
                {Ttl, Count} -> send_frame(S, #{type => ?LEASE, stream => 0, ttl => Ttl, count => Count});
                undefined -> ok
            end,
            St#{setup := true, lifetime := maps:get(lifetime, F)}
    end;
handle(#{type := ?KEEPALIVE, flags := Fl} = F, St = #{sock := S}) ->
    case Fl band ?F_R of
        0 -> ok;
        _ -> send_frame(S, F#{flags => 0})
    end,
    St;
handle(#{type := T, stream := Id} = F, St = #{sock := S, handlers := H}) when T =:= ?RR; T =:= ?FNF; T =:= ?STREAM ->
    Route = route_of(maps:get(meta, F, undefined)),
    case {Route, maps:find(Route, H)} of
        {none, _} ->
            [send_frame(S, #{type => ?ERROR, stream => Id, code => 16#204, data => <<"no route: the request carries no routing metadata">>}) || T =/= ?FNF],
            St;
        {_, error} ->
            [send_frame(S, #{type => ?ERROR, stream => Id, code => 16#204, data => <<"no handler for route ", Route/binary>>}) || T =/= ?FNF],
            St;
        {_, {ok, {Kind, Fun}}} ->
            Conn = self(),
            Data = maps:get(data, F, <<>>),
            P = case {T, Kind} of
                    {?FNF, fnf} ->
                        OnReject = maps:get(reject, St),
                        spawn(fun() -> case catch Fun(Data) of {reject, R} -> OnReject(Route, Data, R); _ -> ok end end);
                    {?RR, rr} ->
                        spawn_link(fun() ->
                                           Out = try {ok, Fun(Data)} catch _:{panic, R} when is_binary(R) -> {error, R}; _:R -> {error, iolist_to_binary(io_lib:format("~p", [R]))} end,
                                           Conn ! {emit, case Out of
                                                             {ok, V} -> #{type => ?PAYLOAD, stream => Id, flags => ?F_N bor ?F_C, data => V};
                                                             {error, E} -> #{type => ?ERROR, stream => Id, code => 16#201, data => E}
                                                         end}
                                   end);
                    {?STREAM, stream} ->
                        N = maps:get(n, F),
                        spawn_link(fun() ->
                                           Items = try {ok, Fun(Data)} catch _:{panic, R} when is_binary(R) -> {error, R}; _:R -> {error, iolist_to_binary(io_lib:format("~p", [R]))} end,
                                           case Items of
                                               {ok, L} -> produce(Conn, Id, L, N);
                                               {error, E} -> Conn ! {emit, #{type => ?ERROR, stream => Id, code => 16#201, data => E}}
                                           end
                                   end);
                    _ ->
                        send_frame(S, #{type => ?ERROR, stream => Id, code => 16#204, data => <<"route ", Route/binary, " does not answer this interaction model">>}),
                        undefined
                end,
            case P of
                undefined -> St;
                _ -> St#{streams := maps:put(Id, P, maps:get(streams, St))}
            end
    end;
handle(#{type := ?REQN, stream := Id, n := N}, St) ->
    case maps:find(Id, maps:get(streams, St)) of {ok, P} -> P ! {credit, N}; error -> ok end, St;
handle(#{type := ?CANCEL, stream := Id}, St) ->
    case maps:find(Id, maps:get(streams, St)) of {ok, P} -> unlink(P), exit(P, kill); error -> ok end,
    St#{streams := maps:remove(Id, maps:get(streams, St))};
handle(_, St) -> St.

%% The producer: emits only against credit.
produce(Conn, Id, [], _) -> Conn ! {emit, #{type => ?PAYLOAD, stream => Id, flags => ?F_C}};
produce(Conn, Id, [I | Rest], 0) ->
    receive {credit, N} -> produce(Conn, Id, [I | Rest], N) end;
produce(Conn, Id, [I | Rest], N) ->
    Conn ! {emit, #{type => ?PAYLOAD, stream => Id, flags => ?F_N, data => I}},
    produce(Conn, Id, Rest, N - 1).

stream_procs(_Port) ->
    case persistent_term:get(rakun_rsocket_last_responder, undefined) of
        undefined -> -1;
        P ->
            case is_process_alive(P) of
                false -> 0;
                true -> P ! {streams, self()}, receive {rakun_rsocket_streams, L} -> length(L) after 1000 -> -1 end
            end
    end.

%% ═══ the requester ═══════════════════════════════════════════════════════════

connect(Host, Port, IntervalMs, LifetimeMs) ->
    Me = self(),
    Pid = spawn(fun() ->
                        case gen_tcp:connect(binary_to_list(Host), Port, [binary, {active, true}], 3000) of
                            {ok, S} ->
                                send_frame(S, #{type => ?SETUP, stream => 0, interval => IntervalMs, lifetime => LifetimeMs, data => <<>>}),
                                erlang:send_after(IntervalMs, self(), keepalive),
                                Me ! {rakun_rsocket_up, self()},
                                qloop(#{sock => S, buf => <<>>, next => 1, waiters => #{}, lease => unlimited, written => 0, interval => IntervalMs});
                            {error, R} -> Me ! {rakun_rsocket_failed, self(), R}
                        end
                end),
    receive
        {rakun_rsocket_up, Pid} -> {ok, Pid};
        {rakun_rsocket_failed, Pid, R} -> {error, iolist_to_binary(io_lib:format("~p", [R]))}
    after 5000 -> {error, <<"connect timed out">>}
    end.

close(C) -> C ! close, ok.

written(C) -> C ! {written, self()}, receive {rakun_rsocket_written, N} -> N after 1000 -> -1 end.

qloop(St = #{sock := S, buf := Buf}) ->
    receive
        {tcp, S, Data} -> qframes(St#{buf := <<Buf/binary, Data/binary>>});
        {tcp_closed, S} ->
            [W ! {rakun_rsocket, error, <<"the connection closed">>} || W <- maps:values(maps:get(waiters, St))],
            ok;
        keepalive -> qsend(St, #{type => ?KEEPALIVE, stream => 0, flags => ?F_R}), erlang:send_after(maps:get(interval, St), self(), keepalive), qloop(St);
        {request, From, Kind, Route, Data, N} ->
            case maps:get(lease, St) of
                0 -> From ! {rakun_rsocket_id, rejected}, qloop(St);
                L ->
                    Id = maps:get(next, St),
                    T = case Kind of rr -> ?RR; fnf -> ?FNF; stream -> ?STREAM end,
                    St1 = qsend(St, #{type => T, stream => Id, meta => route_metadata(Route), data => Data, n => N}),
                    From ! {rakun_rsocket_id, Id},
                    W = case Kind of fnf -> maps:get(waiters, St1); _ -> maps:put(Id, From, maps:get(waiters, St1)) end,
                    qloop(St1#{next := Id + 2, waiters := W, lease := case L of unlimited -> unlimited; _ -> L - 1 end})
            end;
        {reqn, Id, N} -> qloop(qsend(St, #{type => ?REQN, stream => Id, n => N}));
        {cancel, Id} -> qloop((qsend(St, #{type => ?CANCEL, stream => Id}))#{waiters := maps:remove(Id, maps:get(waiters, St))});
        {written, From} -> From ! {rakun_rsocket_written, maps:get(written, St)}, qloop(St);
        close -> gen_tcp:close(S), ok
    end.

qsend(St = #{sock := S}, F) -> gen_tcp:send(S, encode(F)), St#{written := maps:get(written, St) + 1}.

qframes(St = #{buf := Buf}) ->
    case decode(Buf, 16777215) of
        more -> qloop(St);
        {error, _} -> qloop(St#{buf := <<>>});
        {ok, #{type := ?LEASE, count := Count}, Rest} -> qframes(St#{buf := Rest, lease := Count});
        {ok, #{type := ?KEEPALIVE}, Rest} -> qframes(St#{buf := Rest});
        {ok, #{stream := Id} = F, Rest} ->
            case maps:find(Id, maps:get(waiters, St)) of
                {ok, W} -> W ! {rakun_rsocket, Id, F};
                error -> ok
            end,
            qframes(St#{buf := Rest})
    end.

open_stream(C, Kind, Route, Data, N) ->
    C ! {request, self(), Kind, Route, Data, N},
    receive {rakun_rsocket_id, Id} -> Id after 3000 -> timeout end.

request_response(C, Route, Data, Timeout) ->
    case open_stream(C, rr, Route, Data, 0) of
        rejected -> {error, <<"rejected locally: the responder's lease is spent">>};
        timeout -> {error, <<"the connection is gone">>};
        Id ->
            receive
                {rakun_rsocket, Id, #{type := ?PAYLOAD, data := V}} -> {ok, V};
                {rakun_rsocket, Id, #{type := ?ERROR, data := E}} -> {error, E};
                {rakun_rsocket, error, E} -> {error, E}
            after Timeout -> {error, <<"no response">>}
            end
    end.

fire_and_forget(C, Route, Data) ->
    case open_stream(C, fnf, Route, Data, 0) of
        rejected -> {error, <<"rejected locally: the responder's lease is spent">>};
        timeout -> {error, <<"the connection is gone">>};
        _ -> ok
    end.

%% A stream handle is {Conn, Id, Owner}; `next` reads the owner's mailbox.
request_stream(C, Route, Data, N) ->
    case open_stream(C, stream, Route, Data, N) of
        Id when is_integer(Id) -> {ok, Id};
        rejected -> {error, <<"rejected locally: the responder's lease is spent">>};
        timeout -> {error, <<"the connection is gone">>}
    end.

request_n({C, Id}, N) -> C ! {reqn, Id, N}, ok.

next(Id, Timeout) ->
    receive
        {rakun_rsocket, Id, #{type := ?PAYLOAD, flags := Fl} = F} ->
            case Fl band ?F_N of
                0 -> done;
                _ -> {item, maps:get(data, F, <<>>)}
            end;
        {rakun_rsocket, Id, #{type := ?ERROR, data := E}} -> {error, E};
        {rakun_rsocket, error, E} -> {error, E}
    after Timeout -> timeout
    end.

cancel({C, Id}) -> C ! {cancel, Id}, ok.
