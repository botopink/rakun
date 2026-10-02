%%% rakun-cache — the BEAM half of front 12.
%%%
%%% WHAT LIVES HERE AND WHY. Only what botopink cannot hold or reach:
%%%
%%%   * the ETS store. One `set` table for every cache, keyed by
%%%     `{CacheName, Key}`, owned by a dedicated process (`rakun_cache_owner`)
%%%     that does nothing else — a crashing request worker takes no row with
%%%     it, and no atom is minted per cache name. A row is
%%%     `{{Name, Key}, Row, Tags, Marked, Tick, Hits, ExpireAt}`: `Row` is the
%%%     botopink `CacheRow` value, stored opaque; the other columns are what
%%%     tag invalidation and eviction read without decoding it;
%%%   * the cache NAMES table (the resolved settings of every cache created,
%%%     stored opaque) and the customizers (function values);
%%%   * the single-flight table: concurrent misses on one key run ONE loader,
%%%     and the other callers wait for its value;
%%%   * the background refreshes a stale read schedules, and `drain/0`, which
%%%     waits for them;
%%%   * the monotonic clock the freshness arithmetic reads, with a test offset;
%%%   * the invalidation log (`revalidatedTags()` / `revalidatedPaths()`) and
%%%     the outcome trace;
%%%   * a RESP double for the tests (`resp_double_*`): a loopback listener
%%%     that answers GET / SET / DEL / SADD / SMEMBERS / PING and records every
%%%     command, so the Redis provider is exercised without a Redis.
%%%
%%% WHAT DOES NOT LIVE HERE. The key protocol, the lifetimes, the freshness
%%% rule, the provider switch, the kill switch, the legality table and every
%%% refusal text are botopink (`cache.bp`). The Redis wire itself is
%%% rakun-session's (`rakun_session:redis/3`), reused rather than copied.
%%%
%%% MODULE ATOM. `rakun_cache`, never `cache`: the member emits a `cache`
%%% module and `shipErlSidecars` silently skips a qualifier atom that names an
%%% emitted module.
-module(rakun_cache).

-export([row_put/5, row_get/2, row_marked/2, row_delete/2,
         clear_name/1, clear_all/0, size/1, evict_one/3,
         mark_tag/1, expire_tag/1, keys_of/1,
         name_put/2, name_get/1, names/0, names_clear/0,
         customizer_add/1, customizers/0, customizers_clear/0,
         flight/2, refresh/2, drain/0, flights_led/0,
         now/0, clock_advance/1, clock_reset/0, wide/1,
         log_add/2, logged/1, log_clear/1,
         trace_on/0, trace_off/0, trace/1, traced/0,
         owner_alive/0, owner_facts/0, spawn_crash/1,
         resp_double_start/0, resp_double_log/0, resp_double_stop/0,
         spawn_many/2]).

-define(OWNER, rakun_cache_owner).
-define(ROWS, rakun_cache_rows).       %% set: {{Name, Key}, Row, Tags, Marked, Tick, Hits, ExpireAt}
-define(NAMES, rakun_cache_names).     %% set: {Name, Settings}
-define(FLIGHTS, rakun_cache_flights). %% set: {FlightKey, LeaderPid, [Waiter]}
-define(LOG, rakun_cache_log).         %% ordered_set: {Seq, Kind, Value}
-define(CUSTOM, {rakun_cache, customizers}).
-define(OFFSET, {rakun_cache, clock_offset}).
-define(TRACE, {rakun_cache, trace}).

%% ═══ rows ════════════════════════════════════════════════════════════════════

row_put(Name, Key, Row, Tags, ExpireAt) ->
    ensure(),
    true = ets:insert(?ROWS, {{Name, Key}, Row, Tags, false, tick(), 0, ExpireAt}),
    tel(put, Name, <<"stored">>),
    1.

%% Front 75's bus: `[rakun, cache, get|put|evict, stop]` with `cache` and
%% `result` (hit / miss / stored / evicted) when rakun-metrics is in the build.
tel(Op, Name, Result) ->
    case erlang:function_exported(rakun_telemetry, execute, 3) of
        true -> try rakun_telemetry:execute([rakun, cache, Op, stop], #{}, #{cache => Name, result => Result})
                catch _:_ -> ok end;
        false -> ok
    end.

%% A read counts: the tick moves (LRU) and the hit count grows (LFU).
%%
%% The two columns are updated IN PLACE (`update_element` / `update_counter`),
%% never by re-inserting the tuple the read saw: a write-back of `Row` would
%% put back the value a concurrent `row_put` just replaced (or a row a
%% concurrent delete just removed, or clear a concurrent mark), so a reader
%% racing a regeneration resurrected the stale entry and a second
%% regeneration started. A row gone between the lookup and the update is
%% left gone.
row_get(Name, Key) ->
    ensure(),
    K = {Name, Key},
    case ets:lookup(?ROWS, K) of
        [{K, Row, _Tags, _Marked, _Tick, _Hits, _ExpireAt}] ->
            _ = ets:update_element(?ROWS, K, {5, tick()}),
            _ = try ets:update_counter(?ROWS, K, {6, 1}) catch error:badarg -> 0 end,
            tel(get, Name, <<"hit">>),
            Row;
        [] -> tel(get, Name, <<"miss">>), undefined
    end.

row_marked(Name, Key) ->
    ensure(),
    case ets:lookup(?ROWS, {Name, Key}) of
        [{_, _, _, Marked, _, _, _}] -> Marked;
        [] -> false
    end.

row_delete(Name, Key) ->
    ensure(),
    case ets:member(?ROWS, {Name, Key}) of
        true -> true = ets:delete(?ROWS, {Name, Key}), tel(evict, Name, <<"evicted">>), 1;
        false -> 0
    end.

clear_name(Name) ->
    ensure(),
    ets:select_delete(?ROWS, [{{{Name, '_'}, '_', '_', '_', '_', '_', '_'}, [], [true]}]).

clear_all() ->
    ensure(),
    N = ets:info(?ROWS, size),
    true = ets:delete_all_objects(?ROWS),
    N.

size(Name) ->
    ensure(),
    ets:select_count(?ROWS, [{{{Name, '_'}, '_', '_', '_', '_', '_', '_'}, [], [true]}]).

keys_of(Name) ->
    ensure(),
    lists:sort(ets:select(?ROWS, [{{{Name, '$1'}, '_', '_', '_', '_', '_', '_'}, [], ['$1']}])).

%% Discards ONE row of `Name` under `Policy`: `lru` the least recently read or
%% written, `lfu` the least often read (ties: the least recent), `ttl-only`
%% the one nearest its expiry. `Keep` — the row just written — is never the
%% one discarded: under `lfu` it has no reads yet and would always lose.
%% Answers how many rows went (0 or 1).
evict_one(Name, Policy, Keep) ->
    ensure(),
    Rows = [R || {K, _, _, _} = R <- ets:select(?ROWS, [{{{Name, '$1'}, '_', '_', '_', '$2', '$3', '$4'}, [], [{{'$1', '$2', '$3', '$4'}}]}]),
                 K =/= Keep],
    case Rows of
        [] -> 0;
        _ ->
            Rank = case Policy of
                       <<"lfu">> -> fun({_, T, H, _}) -> {H, T} end;
                       <<"ttl-only">> -> fun({_, T, _, E}) -> {E, T} end;
                       _ -> fun({_, T, _, _}) -> T end
                   end,
            [{Key, _, _, _} | _] = lists:sort(fun(A, B) -> Rank(A) =< Rank(B) end, Rows),
            row_delete(Name, Key)
    end.

%% Every row carrying `Tag` is marked stale: the next read serves it once and
%% schedules a refresh. Answers how many rows were marked.
mark_tag(Tag) ->
    ensure(),
    %% The mark is set in place: re-inserting the listed tuple would put back
    %% a row a concurrent `row_put` replaced or a concurrent delete removed.
    Hits = [K || {K, _, Tags, _, _, _, _} <- ets:tab2list(?ROWS), lists:member(Tag, Tags)],
    length([K || K <- Hits, ets:update_element(?ROWS, K, {4, true})]).

%% Every row carrying `Tag` is removed now. Answers how many.
expire_tag(Tag) ->
    ensure(),
    Hits = [K || {K, _, Tags, _, _, _, _} <- ets:tab2list(?ROWS), lists:member(Tag, Tags)],
    lists:foreach(fun(K) -> ets:delete(?ROWS, K) end, Hits),
    length(Hits).

%% ═══ names and customizers ═══════════════════════════════════════════════════

name_put(Name, Settings) ->
    ensure(),
    true = ets:insert(?NAMES, {Name, Settings}),
    0.

name_get(Name) ->
    ensure(),
    case ets:lookup(?NAMES, Name) of
        [{_, S}] -> S;
        [] -> undefined
    end.

names() ->
    ensure(),
    lists:sort([N || {N, _} <- ets:tab2list(?NAMES)]).

names_clear() ->
    ensure(),
    true = ets:delete_all_objects(?NAMES),
    0.

customizer_add(F) ->
    persistent_term:put(?CUSTOM, persistent_term:get(?CUSTOM, []) ++ [F]),
    0.

customizers() ->
    persistent_term:get(?CUSTOM, []).

customizers_clear() ->
    _ = persistent_term:erase(?CUSTOM),
    0.

%% ═══ single flight ═══════════════════════════════════════════════════════════
%%
%% `flight(FlightKey, Load)`: the first caller for a key becomes its leader and
%% runs `Load()` in its own process (so the loader keeps the caller's request
%% frame); every caller arriving while it runs waits for the leader's value
%% instead of running the loader again. A leader that raises re-raises in its
%% own process and tells the waiters, who each retry — one of them leads.
%% The owner process serialises joins, so two callers cannot both lead.

flight(FlightKey, Load) ->
    ensure(),
    case gen_call({join, FlightKey, self()}) of
        lead ->
            try Load() of
                Value ->
                    ?OWNER ! {land, FlightKey, {ok, Value}},
                    Value
            catch
                Class:Reason:Stack ->
                    ?OWNER ! {land, FlightKey, retry},
                    erlang:raise(Class, Reason, Stack)
            end;
        {wait, Ref} ->
            receive
                {Ref, {ok, Value}} -> Value;
                {Ref, retry} -> flight(FlightKey, Load)
            end
    end.

%% How many loads the flights led since the owner started — what the
%% single-flight test counts.
flights_led() ->
    ensure(),
    gen_call(led).

%% Runs `Work()` in a background process unless a refresh of the same key is
%% already running. Answers 1 when it started one, 0 when one was running.
refresh(FlightKey, Work) ->
    ensure(),
    case gen_call({refresh, FlightKey}) of
        start ->
            _ = spawn(fun() ->
                              try Work() catch _:_ -> ok end,
                              ?OWNER ! {refreshed, FlightKey}
                      end),
            1;
        running -> 0
    end.

%% Waits until no refresh is running (at most five seconds). Answers how many
%% were still running when it gave up (0 on success).
drain() ->
    ensure(),
    drain(100).

drain(0) -> gen_call(refreshing);
drain(N) ->
    case gen_call(refreshing) of
        0 -> 0;
        _ -> receive after 50 -> drain(N - 1) end
    end.

gen_call(Msg) ->
    Ref = make_ref(),
    ?OWNER ! {call, self(), Ref, Msg},
    receive {Ref, Reply} -> Reply after 5000 -> erlang:error({rakun_cache_owner_timeout, Msg}) end.

%% ═══ the clock ═══════════════════════════════════════════════════════════════

now() ->
    erlang:monotonic_time(millisecond) + persistent_term:get(?OFFSET, 0).

clock_advance(Ms) ->
    persistent_term:put(?OFFSET, persistent_term:get(?OFFSET, 0) + Ms),
    0.

clock_reset() ->
    _ = persistent_term:erase(?OFFSET),
    0.

wide(N) -> N.

%% ═══ the log and the trace ═══════════════════════════════════════════════════

log_add(Kind, Value) ->
    ensure(),
    true = ets:insert(?LOG, {erlang:unique_integer([monotonic]), Kind, Value}),
    0.

logged(Kind) ->
    ensure(),
    [V || {_, K, V} <- ets:tab2list(?LOG), K =:= Kind].

log_clear(Kind) ->
    ensure(),
    ets:select_delete(?LOG, [{{'_', Kind, '_'}, [], [true]}]).

trace_on() -> persistent_term:put(?TRACE, true), log_clear(<<"trace">>).
trace_off() -> _ = persistent_term:erase(?TRACE), 0.

trace(Line) ->
    case persistent_term:get(?TRACE, false) of
        true -> log_add(<<"trace">>, Line);
        false -> 0
    end.

traced() -> logged(<<"trace">>).

%% ═══ the owner ═══════════════════════════════════════════════════════════════

owner_alive() ->
    case whereis(?OWNER) of
        undefined -> false;
        Pid -> is_process_alive(Pid) andalso ets:whereis(?ROWS) =/= undefined
    end.

owner_facts() ->
    ensure(),
    Owner = ets:info(?ROWS, owner),
    iolist_to_binary(io_lib:format("owner=~s alive=~s caller=~s",
        [case Owner =:= whereis(?OWNER) of true -> "rakun_cache_owner"; false -> "other" end,
         atom_to_list(is_pid(Owner) andalso is_process_alive(Owner)),
         case Owner =:= self() of true -> "owner"; false -> "not-owner" end])).

spawn_crash(Work) ->
    ensure(),
    {Pid, Ref} = spawn_monitor(fun() -> _ = Work(), exit(worker_crashed) end),
    receive
        {'DOWN', Ref, process, Pid, Reason} -> iolist_to_binary(io_lib:format("~p", [Reason]))
    after 5000 -> exit(Pid, kill), <<"timeout">>
    end.

%% Runs `Work(I)` for I in 1..N, each in its own process, all released at
%% once; answers their results in order. What the single-flight test uses to
%% make N callers miss the same key together.
spawn_many(N, Work) ->
    Self = self(),
    Go = make_ref(),
    Pids = [spawn(fun() ->
                          receive Go -> ok end,
                          R = try Work(I) catch C:E -> iolist_to_binary(io_lib:format("~p:~p", [C, E])) end,
                          Self ! {Go, I, R}
                  end) || I <- lists:seq(1, N)],
    [P ! Go || P <- Pids],
    [receive {Go, I, R} -> R after 10000 -> <<"timeout">> end || I <- lists:seq(1, N)].

tick() -> erlang:unique_integer([monotonic]).

ensure() ->
    case ets:whereis(?ROWS) of
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
    case catch erlang:register(?OWNER, self()) of
        true ->
            _ = ets:new(?ROWS, [named_table, public, set]),
            _ = ets:new(?NAMES, [named_table, public, set]),
            _ = ets:new(?LOG, [named_table, public, ordered_set]),
            Caller ! {?OWNER, ready},
            owner_loop(#{}, #{}, 0);
        _ ->
            Caller ! {?OWNER, ready},
            ok
    end.

%% Flights: FlightKey => [{Pid, Ref}] waiters (the key present = a leader runs).
%% Refreshes: FlightKey => true while one runs.
owner_loop(Flights, Refreshes, Led) ->
    receive
        {call, From, Ref, {join, FK, _Pid}} ->
            case maps:find(FK, Flights) of
                error ->
                    From ! {Ref, lead},
                    owner_loop(Flights#{FK => []}, Refreshes, Led + 1);
                {ok, Waiters} ->
                    From ! {Ref, {wait, Ref}},
                    owner_loop(Flights#{FK => [{From, Ref} | Waiters]}, Refreshes, Led)
            end;
        {land, FK, Outcome} ->
            Waiters = maps:get(FK, Flights, []),
            [P ! {R, Outcome} || {P, R} <- Waiters],
            owner_loop(maps:remove(FK, Flights), Refreshes, Led);
        {call, From, Ref, led} ->
            From ! {Ref, Led},
            owner_loop(Flights, Refreshes, Led);
        {call, From, Ref, {refresh, FK}} ->
            case maps:is_key(FK, Refreshes) of
                true -> From ! {Ref, running}, owner_loop(Flights, Refreshes, Led);
                false -> From ! {Ref, start}, owner_loop(Flights, Refreshes#{FK => true}, Led)
            end;
        {refreshed, FK} ->
            owner_loop(Flights, maps:remove(FK, Refreshes), Led);
        {call, From, Ref, refreshing} ->
            From ! {Ref, maps:size(Refreshes)},
            owner_loop(Flights, Refreshes, Led);
        stop -> ok;
        _ -> owner_loop(Flights, Refreshes, Led)
    end.

%% ═══ the RESP double (tests only) ════════════════════════════════════════════
%%
%% A loopback listener answering the handful of commands the Redis provider
%% sends, with a real TTL on SET … EX, and a log of every command received
%% (`GET k`, `SET k v EX 60`, …). Answers the port it listens on.

resp_double_start() ->
    resp_double_stop(),
    Self = self(),
    Pid = spawn(fun() ->
                        {ok, L} = gen_tcp:listen(0, [binary, {active, false}, {packet, raw},
                                                     {reuseaddr, true}, {ip, {127, 0, 0, 1}}]),
                        {ok, Port} = inet:port(L),
                        Store = ets:new(rakun_cache_resp_store, [public, set]),
                        Log = ets:new(rakun_cache_resp_log, [public, ordered_set]),
                        Self ! {resp_ready, Port},
                        resp_accept(L, Store, Log)
                end),
    register(rakun_cache_resp, Pid),
    receive {resp_ready, Port} -> Port after 5000 -> 0 end.

resp_double_stop() ->
    case whereis(rakun_cache_resp) of
        undefined -> 0;
        Pid -> exit(Pid, kill), timer:sleep(10), 1
    end.

resp_double_log() ->
    case whereis(rakun_cache_resp) of
        undefined -> [];
        Pid ->
            Ref = make_ref(),
            Pid ! {log, self(), Ref},
            receive {Ref, Lines} -> Lines after 2000 -> [] end
    end.

resp_accept(L, Store, Log) ->
    case gen_tcp:accept(L, 50) of
        {ok, S} ->
            resp_serve(S, <<>>, Store, Log),
            resp_accept(L, Store, Log);
        {error, timeout} ->
            receive
                {log, From, Ref} ->
                    From ! {Ref, [Line || {_, Line} <- ets:tab2list(Log)]},
                    resp_accept(L, Store, Log)
            after 0 -> resp_accept(L, Store, Log)
            end;
        {error, _} -> ok
    end.

resp_serve(S, Buf, Store, Log) ->
    case resp_parse(Buf) of
        {ok, Args, Rest} ->
            true = ets:insert(Log, {erlang:unique_integer([monotonic]), iolist_to_binary(lists:join(<<" ">>, Args))}),
            ok = gen_tcp:send(S, resp_answer(Args, Store)),
            resp_serve(S, Rest, Store, Log);
        more ->
            case gen_tcp:recv(S, 0, 2000) of
                {ok, Data} -> resp_serve(S, <<Buf/binary, Data/binary>>, Store, Log);
                {error, _} -> gen_tcp:close(S)
            end
    end.

resp_parse(Buf) ->
    case binary:split(Buf, <<"\r\n">>) of
        [<<"*", N/binary>>, Rest] -> resp_bulks(binary_to_integer(N), Rest, []);
        _ -> more
    end.

resp_bulks(0, Rest, Acc) -> {ok, lists:reverse(Acc), Rest};
resp_bulks(N, Buf, Acc) ->
    case binary:split(Buf, <<"\r\n">>) of
        [<<"$", L/binary>>, Rest] ->
            Len = binary_to_integer(L),
            case Rest of
                <<A:Len/binary, "\r\n", After/binary>> -> resp_bulks(N - 1, After, [A | Acc]);
                _ -> more
            end;
        _ -> more
    end.

resp_answer([Cmd | Args], Store) ->
    Now = erlang:monotonic_time(millisecond),
    case {string:uppercase(Cmd), Args} of
        {<<"PING">>, _} -> <<"+PONG\r\n">>;
        {<<"GET">>, [K]} ->
            case ets:lookup(Store, K) of
                [{_, V, Exp}] when Exp =:= 0; Exp > Now -> resp_bulk(V);
                _ -> <<"$-1\r\n">>
            end;
        {<<"SET">>, [K, V, <<"EX">>, Secs]} ->
            true = ets:insert(Store, {K, V, Now + binary_to_integer(Secs) * 1000}),
            <<"+OK\r\n">>;
        {<<"SET">>, [K, V]} ->
            true = ets:insert(Store, {K, V, 0}),
            <<"+OK\r\n">>;
        {<<"DEL">>, Ks} ->
            N = length([K || K <- Ks, ets:member(Store, K)]),
            [ets:delete(Store, K) || K <- Ks],
            [<<":">>, integer_to_binary(N), <<"\r\n">>];
        {<<"SADD">>, [K | Ms]} ->
            Old = case ets:lookup(Store, {set, K}) of [{_, S}] -> S; [] -> [] end,
            New = lists:usort(Old ++ Ms),
            true = ets:insert(Store, {{set, K}, New}),
            [<<":">>, integer_to_binary(length(New) - length(Old)), <<"\r\n">>];
        {<<"SMEMBERS">>, [K]} ->
            Ms = case ets:lookup(Store, {set, K}) of [{_, S}] -> S; [] -> [] end,
            [<<"*">>, integer_to_binary(length(Ms)), <<"\r\n">>, [resp_bulk(M) || M <- Ms]];
        _ -> <<"-ERR unknown command\r\n">>
    end.

resp_bulk(V) -> [<<"$">>, integer_to_binary(byte_size(V)), <<"\r\n">>, V, <<"\r\n">>].
