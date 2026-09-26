%%% rakun-session — the BEAM half of front 18.
%%%
%%% WHAT LIVES HERE AND WHY. Only what botopink cannot hold or reach:
%%%
%%%   * the PER-REQUEST slots (the session loaded or created for the request
%%%     being served, its state, the cookie outcome). A request is a process, so
%%%     they are the process dictionary; the chain entry clears them FIRST on
%%%     every request, because a keep-alive connection serves many requests from
%%%     one process;
%%%   * the INSTALLED repository (a record of closures), a `persistent_term`,
%%%     because a closure is not something a string table holds;
%%%   * the ETS arm's table. An ETS table dies with the process that created
%%%     it, so a dedicated OWNER process creates it and does nothing else — a
%%%     request worker that crashes, or a test process that exits, takes no
%%%     session with it (Step 3's "survives a worker crash");
%%%   * the counters a test double counts store lookups with;
%%%   * the Redis arm's wire: RESP over `gen_tcp`, one connection per command.
%%%
%%% WHAT DOES NOT LIVE HERE. The session value, the id and cookie format, the
%%% HMAC, the constant-time compare, the cookie attributes, the expiry rule,
%%% the arm selection and every refusal text are botopink.
%%%
%%% MODULE ATOM. `rakun_session`, never `session`: the member emits a `session`
%%% module and `shipErlSidecars` silently skips a qualifier atom that names an
%%% emitted module.
-module(rakun_session).

-export([slot_put/2, slot/1, slots_clear/0,
         put_current/1, current/0, clear_current/0,
         install_repo/1, repo/0, uninstall_repo/0,
         bump/1, count/1, count_reset/1,
         ets_put/4, ets_get/2, ets_delete/2, ets_by_principal/2, ets_all/1,
         ets_clear/1, ets_size/1, ets_owner_facts/0, ets_alive/0,
         spawn_crash/1, to_i64/1, wide/1,
         redis/3, redact/1]).

-define(OWNER, rakun_session_owner).
-define(STORE, rakun_session_store).     %% set: {{Store, Id}, Principal, Session}
-define(COUNT, rakun_session_count).     %% set: {Key, N}
-define(REPO, {rakun_session, repo}).

%% ═══ per-request slots ═══════════════════════════════════════════════════════

slot_put(Key, Value) ->
    erlang:put({rakun_session_slot, Key}, Value),
    0.

slot(Key) ->
    case erlang:get({rakun_session_slot, Key}) of
        undefined -> <<>>;
        V -> V
    end.

slots_clear() ->
    [erlang:erase(K) || {{rakun_session_slot, _} = K, _} <- erlang:get()],
    erlang:erase(rakun_session_current),
    0.

put_current(Session) ->
    erlang:put(rakun_session_current, Session),
    0.

current() ->
    case erlang:get(rakun_session_current) of
        undefined -> undefined;
        S -> S
    end.

clear_current() ->
    erlang:erase(rakun_session_current),
    0.

%% ═══ the installed repository ═══════════════════════════════════════════════

install_repo(Repo) ->
    persistent_term:put(?REPO, Repo),
    0.

repo() ->
    persistent_term:get(?REPO, undefined).

uninstall_repo() ->
    _ = persistent_term:erase(?REPO),
    0.

%% ═══ counters ═══════════════════════════════════════════════════════════════

bump(Key) ->
    ensure(),
    ets:update_counter(?COUNT, Key, {2, 1}, {Key, 0}).

count(Key) ->
    ensure(),
    case ets:lookup(?COUNT, Key) of
        [{_, N}] -> N;
        [] -> 0
    end.

count_reset(Key) ->
    ensure(),
    true = ets:insert(?COUNT, {Key, 0}),
    0.

%% ═══ the ETS arm ════════════════════════════════════════════════════════════
%%
%% One table for every ETS store, keyed by `{StoreName, Id}`, so two stores
%% (two tests, two applications in one node) never see each other's sessions
%% and no atom is minted per store.

ets_put(Store, Id, Principal, Session) ->
    ensure(),
    true = ets:insert(?STORE, {{Store, Id}, Principal, Session}),
    1.

ets_get(Store, Id) ->
    ensure(),
    case ets:lookup(?STORE, {Store, Id}) of
        [{_, _, Session}] -> Session;
        [] -> undefined
    end.

ets_delete(Store, Id) ->
    ensure(),
    case ets:member(?STORE, {Store, Id}) of
        true -> true = ets:delete(?STORE, {Store, Id}), 1;
        false -> 0
    end.

ets_by_principal(Store, Principal) ->
    ensure(),
    ets:select(?STORE, [{{{Store, '_'}, Principal, '$1'}, [], ['$1']}]).

ets_all(Store) ->
    ensure(),
    ets:select(?STORE, [{{{Store, '_'}, '_', '$1'}, [], ['$1']}]).

ets_clear(Store) ->
    ensure(),
    ets:select_delete(?STORE, [{{{Store, '_'}, '_', '_'}, [], [true]}]).

ets_size(Store) ->
    length(ets_all(Store)).

%% Who owns the table: the registered owner process, alive, and not the caller.
ets_owner_facts() ->
    ensure(),
    Owner = ets:info(?STORE, owner),
    Named = whereis(?OWNER),
    iolist_to_binary(io_lib:format("owner=~s alive=~s caller=~s",
        [case Owner =:= Named of true -> "rakun_session_owner"; false -> "other" end,
         atom_to_list(is_pid(Owner) andalso is_process_alive(Owner)),
         case Owner =:= self() of true -> "owner"; false -> "not-owner" end])).

ets_alive() ->
    case whereis(?OWNER) of
        undefined -> false;
        Pid -> is_process_alive(Pid) andalso ets:whereis(?STORE) =/= undefined
    end.

%% Runs `Work()` in a fresh process that then CRASHES; answers the exit
%% reason once the process is gone. What the ETS-owner cell uses to prove a
%% worker's death takes no session with it.
spawn_crash(Work) ->
    ensure(),
    {Pid, Ref} = spawn_monitor(fun() -> _ = Work(), exit(worker_crashed) end),
    receive
        {'DOWN', Ref, process, Pid, Reason} ->
            iolist_to_binary(io_lib:format("~p", [Reason]))
    after 5000 ->
        exit(Pid, kill),
        <<"timeout">>
    end.

%% ═══ integers ═══════════════════════════════════════════════════════════════

to_i64(Text) when is_binary(Text) ->
    try binary_to_integer(string:trim(Text)) catch _:_ -> 0 end;
to_i64(N) when is_integer(N) -> N;
to_i64(_) -> 0.

wide(N) -> N.

%% ═══ the Redis arm's wire ═══════════════════════════════════════════════════
%%
%% `redis(Url, Args, TimeoutMs)` opens a connection, AUTHs / SELECTs when the
%% URL says so, sends one command and answers ONE text:
%%
%%   `ok <text>`  a simple string, an integer or a bulk string
%%   `ok <a>\n<b>` an array (members joined by newline; session ids never carry one)
%%   `nil`        a nil reply
%%   `err <text>` a Redis error, a refused connection, a timeout or a bad URL
%%
%% One connection per command: no pool, no pipelining. It is enough for the
%% arm's semantics and it is stated, not hidden.

redis(Url, Args, Timeout) ->
    case parse_url(Url) of
        {error, Why} -> <<"err ", Why/binary>>;
        {ok, Host, Port, Password, Db} ->
            case gen_tcp:connect(binary_to_list(Host), Port,
                                 [binary, {active, false}, {packet, raw}], Timeout) of
                {error, Reason} ->
                    iolist_to_binary(io_lib:format("err unreachable ~s:~p (~p)", [Host, Port, Reason]));
                {ok, Sock} ->
                    try
                        Pre = case Password of
                                  <<>> -> ok;
                                  _ -> command(Sock, [<<"AUTH">>, Password], Timeout)
                              end,
                        Pre2 = case {Pre, Db} of
                                   {ok, <<>>} -> ok;
                                   {ok, _} -> command(Sock, [<<"SELECT">>, Db], Timeout);
                                   _ -> Pre
                               end,
                        case Pre2 of
                            ok -> render(roundtrip(Sock, Args, Timeout));
                            Other -> render(Other)
                        end
                    after
                        gen_tcp:close(Sock)
                    end
            end
    end.

command(Sock, Args, Timeout) ->
    case roundtrip(Sock, Args, Timeout) of
        {ok, _} -> ok;
        Other -> Other
    end.

roundtrip(Sock, Args, Timeout) ->
    Wire = [<<"*">>, integer_to_binary(length(Args)), <<"\r\n">>,
            [[<<"$">>, integer_to_binary(byte_size(A)), <<"\r\n">>, A, <<"\r\n">>] || A <- Args]],
    case gen_tcp:send(Sock, Wire) of
        ok -> read_reply(Sock, <<>>, Timeout);
        {error, R} -> {error, iolist_to_binary(io_lib:format("send ~p", [R]))}
    end.

read_reply(Sock, Buf, Timeout) ->
    case parse(Buf) of
        {done, Value, _Rest} -> Value;
        more ->
            case gen_tcp:recv(Sock, 0, Timeout) of
                {ok, Data} -> read_reply(Sock, <<Buf/binary, Data/binary>>, Timeout);
                {error, R} -> {error, iolist_to_binary(io_lib:format("recv ~p", [R]))}
            end
    end.

parse(<<>>) -> more;
parse(Buf) ->
    case binary:split(Buf, <<"\r\n">>) of
        [_] -> more;
        [<<"+", S/binary>>, Rest] -> {done, {ok, S}, Rest};
        [<<"-", E/binary>>, Rest] -> {done, {error, E}, Rest};
        [<<":", I/binary>>, Rest] -> {done, {ok, I}, Rest};
        [<<"$-1">>, Rest] -> {done, nil, Rest};
        [<<"*-1">>, Rest] -> {done, nil, Rest};
        [<<"$", L/binary>>, Rest] ->
            Len = binary_to_integer(L),
            case Rest of
                <<Bulk:Len/binary, "\r\n", After/binary>> -> {done, {ok, Bulk}, After};
                _ -> more
            end;
        [<<"*", N/binary>>, Rest] -> parse_array(binary_to_integer(N), Rest, []);
        [Other, Rest] -> {done, {error, <<"unexpected reply ", Other/binary>>}, Rest}
    end.

parse_array(0, Rest, Acc) -> {done, {array, lists:reverse(Acc)}, Rest};
parse_array(N, Buf, Acc) ->
    case parse(Buf) of
        more -> more;
        {done, {ok, V}, Rest} -> parse_array(N - 1, Rest, [V | Acc]);
        {done, nil, Rest} -> parse_array(N - 1, Rest, Acc);
        {done, Other, _} -> {done, Other, <<>>}
    end.

render({ok, V}) -> <<"ok ", V/binary>>;
render({array, Vs}) -> iolist_to_binary([<<"ok ">>, lists:join(<<"\n">>, Vs)]);
render(nil) -> <<"nil">>;
render({error, E}) -> <<"err ", E/binary>>.

%% redis://[user][:password@]host[:port][/db]
parse_url(<<"redis://", Rest/binary>>) ->
    {Auth, HostPart} = case binary:split(Rest, <<"@">>) of
                           [A, H] -> {A, H};
                           [H] -> {<<>>, H}
                       end,
    Password = case binary:split(Auth, <<":">>) of
                   [_User, P] -> P;
                   _ -> <<>>
               end,
    {HostPort, Db} = case binary:split(HostPart, <<"/">>) of
                         [HP, D] -> {HP, D};
                         [HP] -> {HP, <<>>}
                     end,
    case binary:split(HostPort, <<":">>) of
        [Host, PortText] ->
            try {ok, Host, binary_to_integer(PortText), Password, Db}
            catch _:_ -> {error, <<"the port of the redis URL is not a number">>}
            end;
        [Host] -> {ok, Host, 6379, Password, Db}
    end;
parse_url(_) ->
    {error, <<"the URL does not start with redis://">>}.

%% A URL fit for a message: the password replaced by `***`.
redact(Url) ->
    case binary:split(Url, <<"@">>) of
        [Head, Tail] ->
            case binary:split(Head, <<":">>, [global]) of
                [Scheme, User, _Pw] -> <<Scheme/binary, ":", User/binary, ":***@", Tail/binary>>;
                _ -> Url
            end;
        _ -> Url
    end.

%% ═══ the owner ══════════════════════════════════════════════════════════════

ensure() ->
    case ets:whereis(?STORE) of
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
    case catch erlang:register(?OWNER, self()) of
        true ->
            _ = ets:new(?STORE, [named_table, public, set, {read_concurrency, true}]),
            _ = ets:new(?COUNT, [named_table, public, set]),
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
