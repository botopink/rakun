%%% rakun-mail — the fixture SMTP server the suite runs against (front 85's
%%% test plan). A listener on an ephemeral port that speaks enough SMTP to
%%% accept a message and records the exact bytes of every command and every
%%% DATA body. `Opts` is a list of binaries:
%%%
%%%   starttls         advertise STARTTLS (needs cert/key)
%%%   implicit         TLS from the first byte (needs cert/key)
%%%   cert=<file> key=<file>
%%%   auth=<MECHS>     advertise `AUTH <MECHS>` (e.g. `PLAIN LOGIN`, `LOGIN`)
%%%   fail=<VERB>:<code>  answer <code> to the first command starting VERB
%%%   silent           accept the connection and never answer
%%%   slow-data=<ms>   stop reading for <ms> once DATA starts
%%%
%%% Test-only: a sidecar here because a `test/` module cannot import a sibling.

-module(rakun_mail_fixture).
-export([start/1, stop/1, messages/1, transcript/1, connections/1, peak/1]).

start(Opts) ->
    Me = self(),
    Pid = spawn(fun() -> init(Me, Opts) end),
    receive {rakun_mail_fixture, Port} -> persistent_term:put({rakun_mail_fixture, Port}, Pid), Port after 5000 -> 0 end.

stop(Port) ->
    case persistent_term:get({rakun_mail_fixture, Port}, undefined) of
        undefined -> 0;
        Pid -> exit(Pid, kill), persistent_term:erase({rakun_mail_fixture, Port}), 0
    end.

opt(Opts, Key) ->
    case [binary:part(O, byte_size(Key) + 1, byte_size(O) - byte_size(Key) - 1) || O <- Opts, binary:match(O, <<Key/binary, "=">>) =:= {0, byte_size(Key) + 1}] of
        [V | _] -> V;
        [] -> <<>>
    end.

has(Opts, Flag) -> lists:member(Flag, Opts).

tab(Port) -> list_to_atom("rakun_mail_fixture_" ++ integer_to_list(Port)).

init(Parent, Opts) ->
    _ = application:ensure_all_started(ssl),
    {ok, L} = gen_tcp:listen(0, [binary, {packet, line}, {active, false}, {reuseaddr, true}]),
    {ok, Port} = inet:port(L),
    T = ets:new(tab(Port), [named_table, public, bag]),
    persistent_term:put({rakun_mail_fixture_ctr, T}, atomics:new(2, [])),
    Parent ! {rakun_mail_fixture, Port},
    accept(L, Opts, T).

accept(L, Opts, T) ->
    case gen_tcp:accept(L) of
        {ok, S} ->
            Pid = spawn(fun() -> receive go -> session(S, Opts, T) end end),
            ok = gen_tcp:controlling_process(S, Pid),
            Pid ! go,
            accept(L, Opts, T);
        _ -> ok
    end.

%% Live connections and their peak, atomically (three sessions race here).
bump(T, D) ->
    try
        Ref = persistent_term:get({rakun_mail_fixture_ctr, T}),
        Live = atomics:add_get(Ref, 1, D),
        case D > 0 of
            true -> ets:insert(T, {conn, Live}), bump_peak(Ref, Live);
            false -> ok
        end
    catch _:_ -> ok
    end.

bump_peak(Ref, Live) ->
    Old = atomics:get(Ref, 2),
    case Live > Old of
        true ->
            case atomics:compare_exchange(Ref, 2, Old, Live) of
                ok -> ok;
                _ -> bump_peak(Ref, Live)
            end;
        false -> ok
    end.

tls_opts(Opts) -> [{certfile, binary_to_list(opt(Opts, <<"cert">>))}, {keyfile, binary_to_list(opt(Opts, <<"key">>))}].

session(S0, Opts, T) ->
    bump(T, 1),
    C = case has(Opts, <<"implicit">>) of
            true ->
                {ok, TS} = ssl:handshake(S0, tls_opts(Opts), 5000),
                {ssl, TS};
            false -> {gen_tcp, S0}
        end,
    Ended = case has(Opts, <<"silent">>) of
                true -> timer:sleep(60000);
                false ->
                    say(C, <<"220 fixture ESMTP">>),
                    serve(C, Opts, T, #{tls => element(1, C) =:= ssl, from => <<>>, rcpts => []})
            end,
    case Ended of quit -> ok; _ -> bump(T, -1) end.

say({M, S}, Line) -> M:send(S, [Line, <<"\r\n">>]).

serve({M, S} = C, Opts, T, St) ->
    case M:recv(S, 0, 10000) of
        {ok, Line0} ->
            Line = strip_eol(Line0),
            ets:insert(T, {cmd, erlang:unique_integer([monotonic]), Line}),
            Verb = string:uppercase(hd(binary:split(Line, [<<" ">>, <<":">>]))),
            case failure(Opts, Line) of
                {true, Code} -> say(C, <<Code/binary, " fixture refuses">>), serve(C, Opts, T, St);
                false -> command(Verb, Line, C, Opts, T, St)
            end;
        _ -> M:close(S)
    end.

failure(Opts, Line) ->
    case opt(Opts, <<"fail">>) of
        <<>> -> false;
        F ->
            [V, Code] = binary:split(F, <<":">>),
            case string:prefix(string:uppercase(Line), string:uppercase(V)) of
                nomatch -> false;
                _ -> {true, Code}
            end
    end.

command(<<"EHLO">>, _, C, Opts, T, St) ->
    Auth = opt(Opts, <<"auth">>),
    Caps = [<<"fixture">>, <<"8BITMIME">>]
        ++ [<<"STARTTLS">> || has(Opts, <<"starttls">>), maps:get(tls, St) =:= false]
        ++ [<<"AUTH ", Auth/binary>> || Auth =/= <<>>],
    Last = length(Caps),
    [say(C, <<"250", (case I of Last -> <<" ">>; _ -> <<"-">> end)/binary, Cap/binary>>) || {I, Cap} <- lists:zip(lists:seq(1, Last), Caps)],
    serve(C, Opts, T, St);
command(<<"STARTTLS">>, _, {gen_tcp, S} = C, Opts, T, St) ->
    say(C, <<"220 go ahead">>),
    {ok, TS} = ssl:handshake(S, tls_opts(Opts), 5000),
    serve({ssl, TS}, Opts, T, St#{tls := true});
command(<<"AUTH">>, Line, C, Opts, T, St) ->
    case string:uppercase(Line) of
        <<"AUTH LOGIN", _/binary>> ->
            say(C, <<"334 VXNlcm5hbWU6">>),
            {ok, U} = recv(C),
            say(C, <<"334 UGFzc3dvcmQ6">>),
            {ok, P} = recv(C),
            ets:insert(T, {auth, <<"LOGIN">>, base64:decode(trim(U)), base64:decode(trim(P))});
        _ ->
            [_, _, B] = binary:split(Line, <<" ">>, [global]),
            [_, U, P] = binary:split(base64:decode(B), <<0>>, [global]),
            ets:insert(T, {auth, <<"PLAIN">>, U, P})
    end,
    say(C, <<"235 ok">>),
    serve(C, Opts, T, St);
command(<<"MAIL">>, Line, C, Opts, T, St) ->
    say(C, <<"250 ok">>),
    serve(C, Opts, T, St#{from := addr(Line), rcpts := []});
command(<<"RCPT">>, Line, C, Opts, T, St) ->
    say(C, <<"250 ok">>),
    serve(C, Opts, T, St#{rcpts := maps:get(rcpts, St) ++ [addr(Line)]});
command(<<"DATA">>, _, C, Opts, T, St) ->
    say(C, <<"354 end with .">>),
    case opt(Opts, <<"slow-data">>) of
        <<>> -> ok;
        Ms -> timer:sleep(binary_to_integer(Ms))
    end,
    Data = data(C, []),
    ets:insert(T, {msg, erlang:unique_integer([monotonic]), maps:get(from, St), maps:get(rcpts, St), Data, maps:get(tls, St)}),
    say(C, <<"250 queued">>),
    serve(C, Opts, T, St);
command(<<"QUIT">>, _, {M, S} = C, _, T, _) ->
    bump(T, -1),
    say(C, <<"221 bye">>),
    M:close(S),
    quit;
command(_, _, C, Opts, T, St) ->
    say(C, <<"250 ok">>),
    serve(C, Opts, T, St).

recv({M, S}) -> M:recv(S, 0, 10000).
trim(B) -> strip_eol(B).

addr(Line) ->
    case binary:split(Line, <<"<">>) of
        [_, R] -> hd(binary:split(R, <<">">>));
        _ -> <<>>
    end.

%% The DATA body exactly as sent (dot-stuffing and CRLFs kept), up to the
%% terminating `.` line.
data(C, Acc) ->
    {ok, L} = recv(C),
    case L of
        <<".\r\n">> -> iolist_to_binary(lists:reverse(Acc));
        _ -> data(C, [L | Acc])
    end.

%% `from\trcpt,rcpt\ttls\n<data>` per message, oldest first.
messages(Port) ->
    Ms = lists:sort([{I, F, R, D, TLS} || {msg, I, F, R, D, TLS} <- ets:tab2list(tab(Port))]),
    [iolist_to_binary([F, "\t", lists:join(",", R), "\t", atom_to_list(TLS), "\n", D]) || {_, F, R, D, TLS} <- Ms].

%% Every command line received, oldest first, then `AUTH <mech> <user> <pass>` rows.
transcript(Port) ->
    Cmds = [L || {_, L} <- lists:sort([{I, L} || {cmd, I, L} <- ets:tab2list(tab(Port))])],
    Auths = [iolist_to_binary(["AUTH-USED ", M, " ", U, " ", P]) || {auth, M, U, P} <- ets:tab2list(tab(Port))],
    Cmds ++ Auths.

connections(Port) -> length([x || {conn, _} <- ets:tab2list(tab(Port))]).

peak(Port) -> atomics:get(persistent_term:get({rakun_mail_fixture_ctr, tab(Port)}), 2).

strip_eol(B) ->
    case B of
        <<>> -> B;
        _ ->
            case binary:last(B) of
                C when C =:= $\r; C =:= $\n -> strip_eol(binary:part(B, 0, byte_size(B) - 1));
                _ -> B
            end
    end.
