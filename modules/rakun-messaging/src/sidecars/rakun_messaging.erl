%%% rakun-messaging — the BEAM half of front 15.
%%%
%%% WHAT LIVES HERE AND WHY. Only what botopink cannot hold or reach:
%%%
%%%   * the LISTENER registry: `{Seq, Name, Broker, Destination, Group,
%%%     Container, Invoke}` in registration order, where `Invoke` is the
%%%     botopink closure that builds the `Message` and calls the handler; and
%%%     every duplicate `{Broker, Destination}` seen, so the boot can refuse it
%%%     naming both handlers;
%%%   * the IN-PROCESS broker, the one transport every arm has this milestone:
%%%     an append-only log per `{Broker, Destination}` (`rakun_msg_log`), and per
%%%     consumer group a cursor, a redelivery list and the in-flight set, kept by
%%%     the owner process, which monitors every worker holding a message. A
%%%     queue (AMQP) is a log plus one shared cursor; a Kafka topic or a stream
%%%     is the same log read per group with its offsets exposed; Redis pub/sub
%%%     starts its cursor at the end and never re-delivers;
%%%   * the CONTAINERS: one `simple_one_for_one` supervisor per container,
%%%     started as a `temporary` child of rakun's own `rakun_sup` (front 04's
%%%     tree), with N worker processes. A worker is not caught: a handler that
%%%     raises kills its worker, the supervisor restarts it, and the owner puts
%%%     the dead worker's in-flight messages back at the head of the group;
%%%   * the arms' connection state, the passthrough properties handed to each
%%%     arm, the published log and the startup log.
%%%
%%% WHAT DOES NOT LIVE HERE. The `Message` value, the settings and their
%%% refusals, the ack-mode rule per arm, the listener markers and every
%%% message text are botopink.
%%%
%%% MODULE ATOM. `rakun_messaging`, never `messaging`.
-module(rakun_messaging).
-behaviour(supervisor).

-export([register/6, listener_count/0, listener_destinations/0, listener_names/0,
         listeners/0, duplicates/0, lookup/2, invoke_direct/6, reset/0,
         arm_connect/2, arm_disconnect/1, arm_connected/1, arm_properties/1,
         props_under/1,
         publish/4, published/1, published_clear/0,
         start_container/7, stop_containers/0, container_workers/1, container_alive/1,
         kill_worker/2, kill_container/1, inflight/1, containers/0,
         ack/0, nack/0, current_tag/0, deliveries/1,
         log_line/1, log_lines/0, log_clear/0,
         wait_until/2, wide/1, bump/1, count/1]).
-export([init/1, start_container_sup/1, start_worker/7, worker_init/7]).

-define(OWNER, rakun_messaging_owner).
-define(LISTENERS, rakun_msg_listeners). %% ordered_set {Seq, Name, Broker, Dest, Group, Container, Invoke}
-define(DUPS, rakun_msg_dups).           %% ordered_set {Seq, Broker, Dest, First, Second}
-define(LOG, rakun_msg_log).             %% ordered_set {{Broker, Dest, Offset}, Key, Payload, Headers}
-define(PUBLISHED, rakun_msg_published). %% ordered_set {Seq, Arm, Dest, Key, Payload}
-define(ARMS, rakun_msg_arms).           %% set {Arm, Connected, Properties}
-define(CONTAINERS, rakun_msg_containers). %% set {Name, SupPid, Broker, Dest}
-define(LINES, rakun_msg_lines).         %% ordered_set {Seq, Line}
-define(COUNTS, rakun_msg_counts).       %% set {Key, N}

%% ═══ the registry ════════════════════════════════════════════════════════════

register(Name, Broker, Dest, Group, Container, Invoke) ->
    ensure(),
    case [N || {_, N, B, D, _, _, _} <- ets:tab2list(?LISTENERS), B =:= Broker, D =:= Dest] of
        [First | _] ->
            true = ets:insert(?DUPS, {seq(), Broker, Dest, First, Name});
        [] -> ok
    end,
    true = ets:insert(?LISTENERS, {seq(), Name, Broker, Dest, Group, Container, Invoke}),
    persistent_term:put(rakun_listener_names, fun ?MODULE:listener_destinations/0),
    0.

listener_count() ->
    ensure(),
    ets:info(?LISTENERS, size).

listener_destinations() ->
    ensure(),
    [D || {_, _, _, D, _, _, _} <- ets:tab2list(?LISTENERS)].

listener_names() ->
    ensure(),
    [N || {_, N, _, _, _, _, _} <- ets:tab2list(?LISTENERS)].

%% `name|broker|destination|group|container`, registration order.
listeners() ->
    ensure(),
    [iolist_to_binary([N, "|", B, "|", D, "|", G, "|", C]) || {_, N, B, D, G, C, _} <- ets:tab2list(?LISTENERS)].

%% `broker|destination|first|second` for every duplicate registration.
duplicates() ->
    ensure(),
    [iolist_to_binary([B, "|", D, "|", F, "|", S]) || {_, B, D, F, S} <- ets:tab2list(?DUPS)].

lookup(Broker, Dest) ->
    ensure(),
    case [I || {_, _, B, D, _, _, I} <- ets:tab2list(?LISTENERS), B =:= Broker, D =:= Dest] of
        [I | _] -> I;
        [] -> undefined
    end.

%% Calls the registered handler in THIS process, no broker involved.
invoke_direct(Broker, Dest, Key, Payload, Headers, Offset) ->
    case lookup(Broker, Dest) of
        undefined -> erlang:error({rakun_messaging, iolist_to_binary(
                         ["rakun-messaging: no listener consumes ", Broker, " ", Dest])});
        Invoke ->
            put(rakun_msg_tag, direct),
            try Invoke(Broker, Dest, Key, Payload, Headers, Offset)
            after erase(rakun_msg_tag), erase(rakun_msg_settled)
            end
    end.

%% Stops every container and forgets every listener, message, arm and line.
reset() ->
    ensure(),
    stop_containers(),
    [true = ets:delete_all_objects(T) || T <- [?LISTENERS, ?DUPS, ?LOG, ?PUBLISHED, ?ARMS, ?LINES, ?COUNTS]],
    call(reset),
    0.

%% ═══ arms ════════════════════════════════════════════════════════════════════

arm_connect(Arm, Properties) ->
    ensure(),
    true = ets:insert(?ARMS, {Arm, true, Properties}),
    0.

arm_disconnect(Arm) ->
    ensure(),
    case ets:lookup(?ARMS, Arm) of
        [{_, _, P}] -> true = ets:insert(?ARMS, {Arm, false, P}), 1;
        [] -> 0
    end.

arm_connected(Arm) ->
    ensure(),
    case ets:lookup(?ARMS, Arm) of
        [{_, C, _}] -> C;
        [] -> false
    end.

arm_properties(Arm) ->
    ensure(),
    case ets:lookup(?ARMS, Arm) of
        [{_, _, P}] -> P;
        [] -> []
    end.

%% Every property whose key starts with `Prefix`, as `key=value`, sorted by key
%% — read from the core's property table.
props_under(Prefix) ->
    rakun_runtime:ensure_started(),
    L = byte_size(Prefix),
    lists:sort([<<K/binary, "=", V/binary>> || {K, V} <- ets:tab2list(rakun_props),
                                               is_binary(K), byte_size(K) > L,
                                               binary:part(K, 0, L) =:= Prefix]).

%% ═══ publishing ══════════════════════════════════════════════════════════════
%%
%% Appends to the destination's log when the arm is connected; answers 0, or 1
%% when it is not (nothing is appended, nothing raises).

publish(Arm, Dest, Key, Payload) ->
    ensure(),
    case arm_connected(Arm) of
        false -> 1;
        true ->
            true = ets:insert(?PUBLISHED, {seq(), Arm, Dest, Key, Payload}),
            call({append, Arm, Dest, Key, Payload}),
            tel(publish, Arm, Dest),
            0
    end.

%% Front 75's bus: `[rakun, messaging, publish|consume, stop]` with `broker`
%% and `destination` when rakun-metrics is in the build.
tel(Op, Broker, Dest) ->
    case erlang:function_exported(rakun_telemetry, execute, 3) of
        true -> try rakun_telemetry:execute([rakun, messaging, Op, stop], #{}, #{broker => Broker, destination => Dest})
                catch _:_ -> ok end;
        false -> ok
    end.

%% `destination|key|payload`, publish order.
published(Arm) ->
    ensure(),
    [iolist_to_binary([D, "|", K, "|", P]) || {_, A, D, K, P} <- ets:tab2list(?PUBLISHED), A =:= Arm].

published_clear() ->
    ensure(),
    true = ets:delete_all_objects(?PUBLISHED),
    0.

%% ═══ containers ══════════════════════════════════════════════════════════════
%%
%% `start_container(Name, Broker, Dest, Group, Concurrency, Prefetch, AckMode)`
%% plus the start offset carried in `Group` for a stream (`group@offset`).

start_container(Name, Broker, Dest, Group, Concurrency, Prefetch, AckMode) ->
    ensure(),
    rakun_runtime:ensure_started(),
    Invoke = lookup(Broker, Dest),
    {GroupName, Start} = case binary:split(Group, <<"@">>) of
                             [G, S] -> {G, S};
                             [G] -> {G, <<"first">>}
                         end,
    call({open_group, Broker, Dest, GroupName, Start}),
    Spec = #{id => {rakun_messaging_container, Name},
             start => {?MODULE, start_container_sup, [Name]},
             restart => temporary, shutdown => infinity,
             type => supervisor, modules => [?MODULE]},
    _ = supervisor:terminate_child(rakun_sup, {rakun_messaging_container, Name}),
    _ = supervisor:delete_child(rakun_sup, {rakun_messaging_container, Name}),
    {ok, Sup} = supervisor:start_child(rakun_sup, Spec),
    true = ets:insert(?CONTAINERS, {Name, Sup, Broker, Dest}),
    [{ok, _} = supervisor:start_child(Sup, [Name, Broker, Dest, GroupName, Invoke, Prefetch, AckMode])
     || _ <- lists:seq(1, Concurrency)],
    Concurrency.

start_container_sup(Name) ->
    supervisor:start_link(?MODULE, {container, Name}).

init({container, _Name}) ->
    Flags = #{strategy => simple_one_for_one, intensity => 100, period => 10},
    Child = #{id => rakun_messaging_worker,
              start => {?MODULE, start_worker, []},
              restart => permanent, shutdown => brutal_kill,
              type => worker, modules => [?MODULE]},
    {ok, {Flags, [Child]}}.

stop_containers() ->
    ensure(),
    [begin
         _ = supervisor:terminate_child(rakun_sup, {rakun_messaging_container, N}),
         _ = supervisor:delete_child(rakun_sup, {rakun_messaging_container, N})
     end || {N, _, _, _} <- ets:tab2list(?CONTAINERS)],
    true = ets:delete_all_objects(?CONTAINERS),
    0.

containers() ->
    ensure(),
    lists:sort([N || {N, _, _, _} <- ets:tab2list(?CONTAINERS)]).

sup_of(Name) ->
    case ets:lookup(?CONTAINERS, Name) of
        [{_, Sup, _, _}] -> Sup;
        [] -> undefined
    end.

%% Live workers under the container's supervisor, read off the tree itself.
container_workers(Name) ->
    ensure(),
    case sup_of(Name) of
        undefined -> 0;
        Sup ->
            case is_process_alive(Sup) of
                false -> 0;
                true -> length([P || {_, P, worker, _} <- supervisor:which_children(Sup),
                                     is_pid(P), is_process_alive(P)])
            end
    end.

container_alive(Name) ->
    container_workers(Name) > 0.

%% Kills the `Index`-th worker (1-based) and answers its pid as text.
kill_worker(Name, Index) ->
    ensure(),
    case sup_of(Name) of
        undefined -> <<"">>;
        Sup ->
            Pids = [P || {_, P, worker, _} <- supervisor:which_children(Sup), is_pid(P)],
            P = lists:nth(Index, Pids),
            exit(P, kill),
            iolist_to_binary(pid_to_list(P))
    end.

%% Kills the container's supervisor, and with it every worker: nothing
%% restarts it (it is a temporary child), which is what "every worker of the
%% container is down" looks like.
kill_container(Name) ->
    ensure(),
    case sup_of(Name) of
        undefined -> 0;
        Sup -> unlink(Sup), exit(Sup, kill), wait_until(1000, fun() -> not is_process_alive(Sup) end), 1
    end.

%% Messages held in flight by the container's workers (delivered, unsettled).
inflight(Name) ->
    ensure(),
    call({inflight, Name}).

%% How many times the message at `Offset`-th publish position was delivered
%% to a worker — by destination: `broker|dest` → a list of `offset:count`.
deliveries(Key) ->
    ensure(),
    case ets:lookup(?COUNTS, Key) of
        [{_, N}] -> N;
        [] -> 0
    end.

%% ═══ workers ═════════════════════════════════════════════════════════════════

start_worker(Name, Broker, Dest, Group, Invoke, Prefetch, AckMode) ->
    Pid = proc_lib:spawn_link(?MODULE, worker_init, [Name, Broker, Dest, Group, Invoke, Prefetch, AckMode]),
    {ok, Pid}.

%% A worker joins its group and then only receives: the owner PUSHES it up to
%% `Prefetch` unsettled messages (AMQP's `basic.qos`), the way a broker
%% delivers to a consumer, and tops it up as it settles them.
worker_init(Name, Broker, Dest, Group, Invoke, Prefetch, AckMode) ->
    call({join, Name, self(), {Broker, Dest, Group}, Prefetch, AckMode}),
    worker_loop(Broker, Dest, Group, Invoke, AckMode).

worker_loop(Broker, Dest, Group, Invoke, AckMode) ->
    receive
        {deliver, M} -> handle(Broker, Dest, Group, Invoke, AckMode, M)
    end,
    worker_loop(Broker, Dest, Group, Invoke, AckMode).

handle(Broker, Dest, Group, Invoke, AckMode, {Offset, Key, Payload, Headers}) ->
    Tag = {Broker, Dest, Group, Offset},
    bump(iolist_to_binary([Broker, "|", Dest, "|", integer_to_binary(Offset)])),
    put(rakun_msg_tag, Tag),
    erase(rakun_msg_settled),
    Shown = case Broker of
                <<"kafka">> -> Offset;
                <<"stream">> -> Offset;
                _ -> -1
            end,
    _ = Invoke(Broker, Dest, Key, Payload, Headers, Shown),
    tel(consume, Broker, Dest),
    case {AckMode, get(rakun_msg_settled)} of
        {<<"none">>, _} -> ok;
        {<<"auto">>, _} -> call({settle, Tag, ack});
        {<<"manual">>, undefined} -> call({settle, Tag, requeue});
        {<<"manual">>, _} -> ok
    end,
    erase(rakun_msg_tag),
    ok.

%% `ackMessage` / `nackMessage` inside a handler: settle the message being
%% handled. Outside a container (a direct delivery) they settle nothing.
ack() -> settle(ack).
nack() -> settle(requeue).

settle(How) ->
    case get(rakun_msg_tag) of
        undefined -> 0;
        direct -> 0;
        Tag ->
            case get(rakun_msg_settled) of
                undefined -> put(rakun_msg_settled, How), call({settle, Tag, How}), 0;
                _ -> 0
            end
    end.

current_tag() ->
    case get(rakun_msg_tag) of
        {B, D, G, O} -> iolist_to_binary([B, "|", D, "|", G, "|", integer_to_binary(O)]);
        _ -> <<"">>
    end.

%% ═══ the startup log ═════════════════════════════════════════════════════════

log_line(Line) ->
    ensure(),
    true = ets:insert(?LINES, {seq(), Line}),
    io:format("rakun-messaging: ~ts~n", [Line]),
    0.

log_lines() ->
    ensure(),
    [L || {_, L} <- ets:tab2list(?LINES)].

log_clear() ->
    ensure(),
    true = ets:delete_all_objects(?LINES),
    0.

%% Polls `Probe()` every 10 ms until it answers true or `Ms` pass; answers the
%% last answer. What a test waits on a worker with.
wait_until(Ms, Probe) ->
    case Probe() of
        true -> true;
        false when Ms =< 0 -> false;
        false -> receive after 10 -> wait_until(Ms - 10, Probe) end
    end.

wide(N) -> N.

%% ═══ the owner ═══════════════════════════════════════════════════════════════
%%
%% Groups: {Broker, Dest, Group} => #{cursor => N, redeliver => [Offset],
%% inflight => #{Offset => Pid}}. Workers: Pid => Container name (monitored).

call(Msg) ->
    Ref = make_ref(),
    ?OWNER ! {call, self(), Ref, Msg},
    receive {Ref, Reply} -> Reply after 5000 -> erlang:error({rakun_messaging_owner_timeout, Msg}) end.

owner_loop(S) ->
    receive
        {call, From, Ref, Msg} ->
            {Reply, S2} = owner_call(Msg, S),
            From ! {Ref, Reply},
            owner_loop(dispatch_all(S2));
        {'DOWN', _, process, Pid, _} ->
            %% A worker died: everything it held goes back to the head of its group.
            #{groups := Groups, workers := Workers} = S,
            Groups2 = maps:map(fun(_, G = #{inflight := In, redeliver := Re}) ->
                                       Mine = lists:sort([O || {O, P} <- maps:to_list(In), P =:= Pid]),
                                       G#{inflight := maps:filter(fun(_, P) -> P =/= Pid end, In),
                                          redeliver := Mine ++ Re}
                               end, Groups),
            owner_loop(dispatch_all(S#{groups := Groups2, workers := maps:remove(Pid, Workers)}));
        _ -> owner_loop(S)
    after 50 ->
        %% An arm may have been (re)connected from outside the owner.
        owner_loop(dispatch_all(S))
    end.

owner_call(reset, S) ->
    {ok, S#{groups := #{}, heads := #{}}};
owner_call(kick, S) ->
    {ok, S};
owner_call({append, Broker, Dest, Key, Payload}, S = #{heads := Heads}) ->
    Offset = maps:get({Broker, Dest}, Heads, 0),
    true = ets:insert(?LOG, {{Broker, Dest, Offset}, Key, Payload, <<"{}">>}),
    {ok, S#{heads := Heads#{{Broker, Dest} => Offset + 1}}};
owner_call({open_group, Broker, Dest, Group, Start}, S = #{groups := Groups, heads := Heads}) ->
    K = {Broker, Dest, Group},
    case maps:is_key(K, Groups) of
        true -> {ok, S};
        false ->
            Head = maps:get({Broker, Dest}, Heads, 0),
            Cursor = case {Broker, Start} of
                         {<<"redis">>, _} -> Head;
                         {_, <<"first">>} -> 0;
                         {_, <<"next">>} -> Head;
                         {_, <<"last">>} -> max(0, Head - 1);
                         {_, N} -> binary_to_integer(N)
                     end,
            {ok, S#{groups := Groups#{K => #{cursor => Cursor, redeliver => [], inflight => #{}}}}}
    end;
owner_call({join, Name, Pid, K, Prefetch, AckMode}, S = #{workers := Workers}) ->
    _ = erlang:monitor(process, Pid),
    {ok, S#{workers := Workers#{Pid => #{name => Name, key => K, prefetch => Prefetch, ack => AckMode}}}};
owner_call({settle, {Broker, Dest, Group, Offset}, How}, S = #{groups := Groups}) ->
    K = {Broker, Dest, Group},
    case maps:find(K, Groups) of
        error -> {ok, S};
        {ok, G = #{inflight := In, redeliver := Re}} ->
            G2 = case How of
                     ack -> G#{inflight := maps:remove(Offset, In)};
                     requeue -> G#{inflight := maps:remove(Offset, In), redeliver := Re ++ [Offset]}
                 end,
            {ok, S#{groups := Groups#{K => G2}}}
    end;
owner_call({inflight, Name}, S = #{groups := Groups, workers := Workers}) ->
    Mine = [P || {P, #{name := N}} <- maps:to_list(Workers), N =:= Name],
    N = lists:sum([length([O || {O, P} <- maps:to_list(In), lists:member(P, Mine)])
                   || #{inflight := In} <- maps:values(Groups)]),
    {N, S};
owner_call(_, S) ->
    {ok, S}.

%% Pushes every deliverable message to a worker with room, per group: the
%% redelivery list first, then the log from the cursor. A worker has room
%% while it holds fewer than its prefetch unsettled (ack-mode none holds
%% nothing). Nothing moves while the arm is disconnected.
dispatch_all(S = #{groups := Groups}) ->
    lists:foldl(fun(K, Acc) -> dispatch(K, Acc) end, S, maps:keys(Groups)).

dispatch(K = {Broker, Dest, _Group}, S = #{groups := Groups, workers := Workers, heads := Heads}) ->
    case arm_connected(Broker) of
        false -> S;
        true ->
            G = #{cursor := Cursor, redeliver := Re, inflight := In} = maps:get(K, Groups),
            Head = maps:get({Broker, Dest}, Heads, 0),
            Mine = [{P, W} || {P, W = #{key := WK}} <- maps:to_list(Workers), WK =:= K, is_process_alive(P)],
            Next = case Re of
                       [R | _] -> {redeliver, R};
                       [] when Cursor < Head -> {fresh, Cursor};
                       [] -> none
                   end,
            Room = [{held(P, In), P, W} || {P, W = #{prefetch := Pf, ack := A}} <- Mine,
                                            A =:= <<"none">> orelse held(P, In) < Pf],
            case {Next, lists:sort(Room)} of
                {none, _} -> S;
                {_, []} -> S;
                {{Kind, O}, [{_, P, #{ack := A}} | _]} ->
                    [{_, Key, Payload, Headers}] = ets:lookup(?LOG, {Broker, Dest, O}),
                    H = case Kind of redeliver -> <<"{\"redelivered\":true}">>; fresh -> Headers end,
                    P ! {deliver, {O, Key, Payload, H}},
                    In2 = case A of <<"none">> -> In; _ -> In#{O => P} end,
                    G2 = case Kind of
                             redeliver -> G#{redeliver := tl(Re), inflight := In2};
                             fresh -> G#{cursor := Cursor + 1, inflight := In2}
                         end,
                    dispatch(K, S#{groups := Groups#{K => G2}})
            end
    end.

held(P, In) -> length([x || {_, Q} <- maps:to_list(In), Q =:= P]).

%% An atomic counter by key (deliveries use it; so may a test's handler).
bump(Key) ->
    ensure(),
    ets:update_counter(?COUNTS, Key, {2, 1}, {Key, 0}).

count(Key) -> deliveries(Key).

seq() -> erlang:unique_integer([monotonic, positive]).

ensure() ->
    case ets:whereis(?LISTENERS) of
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
            Pub = [named_table, public],
            _ = ets:new(?LISTENERS, [ordered_set | Pub]),
            _ = ets:new(?DUPS, [ordered_set | Pub]),
            _ = ets:new(?LOG, [ordered_set | Pub]),
            _ = ets:new(?PUBLISHED, [ordered_set | Pub]),
            _ = ets:new(?ARMS, [set | Pub]),
            _ = ets:new(?CONTAINERS, [set | Pub]),
            _ = ets:new(?LINES, [ordered_set | Pub]),
            _ = ets:new(?COUNTS, [set | Pub]),
            Caller ! {?OWNER, ready},
            owner_loop(#{groups => #{}, workers => #{}, heads => #{}});
        _ ->
            Caller ! {?OWNER, ready},
            ok
    end.
