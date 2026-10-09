%%% rakun-stream — the stage processes (front 89): GenStage's shape without
%%% the library. Each stage of a running pipeline is a process registered as
%%% `rakun_stream__<pipeline>__<index>` that ACCEPTS an offered event only
%%% while it holds fewer than `Demand` (events buffered plus the one in hand),
%%% so demand flows backwards: an upstream offer blocks until the stage has
%%% room, and a source blocked in an offer holds its broker message unsettled.
%%% A stage runs its step (a botopink closure answering 0..n outputs) and
%%% offers each output downstream; the last stage hands to the sink.
%%%
%%% A keeper process per pipeline monitors the stages and restarts one that
%%% dies, alone, under the same name (its buffer is lost; what it had already
%%% handed downstream is not). A step that raises calls the pipeline's
%%% `OnPoison(StageName, Item, Reason)` and the stage carries on.

-module(rakun_stream).
-compile(nowarn_deprecated_catch).
-export([start/5, stop/1, push/2, stage_pids/1, kill_stage/2, peaks/1, collect/2, collected/1,
         clear_collected/1, running/1]).

name(P, I) -> list_to_atom("rakun_stream__" ++ binary_to_list(P) ++ "__" ++ integer_to_list(I)).

peaks_tab() ->
    case ets:whereis(rakun_stream_peaks) of
        undefined ->
            Me = self(),
            spawn(fun() ->
                          case (catch ets:new(rakun_stream_peaks, [named_table, public, set])) of
                              {'EXIT', _} -> Me ! ready;
                              _ -> ets:new(rakun_stream_collect, [named_table, public, bag]), Me ! ready, receive stop -> ok end
                          end
                  end),
            receive ready -> ok after 2000 -> ok end;
        _ -> ok
    end.

%% Steps: [{StageName, Step}] with Step(Item) -> [Out]; Sink(Item) -> 0 | error text.
start(P, Steps, Sink, Demand, OnPoison) ->
    peaks_tab(),
    _ = stop(P),
    Me = self(),
    K = spawn(fun() -> keeper(Me, P, Steps, Sink, Demand, OnPoison) end),
    receive {rakun_stream_up, K} -> ok after 5000 -> ok end,
    persistent_term:put({rakun_stream_keeper, P}, K),
    length(Steps).

stop(P) ->
    case persistent_term:get({rakun_stream_keeper, P}, undefined) of
        undefined -> 0;
        K ->
            Ref = erlang:monitor(process, K),
            K ! stop,
            receive {'DOWN', Ref, _, _, _} -> ok after 2000 -> exit(K, kill) end,
            persistent_term:erase({rakun_stream_keeper, P}),
            1
    end.

running(P) -> persistent_term:get({rakun_stream_keeper, P}, undefined) =/= undefined.

keeper(Parent, P, Steps, Sink, Demand, OnPoison) ->
    process_flag(trap_exit, true),
    N = length(Steps),
    Specs = lists:zip(lists:seq(1, N), Steps),
    Pids = maps:from_list([{I, spawn_stage(P, I, N, Step, Sink, Demand, OnPoison)} || {I, Step} <- Specs]),
    Parent ! {rakun_stream_up, self()},
    keeper_loop(P, maps:from_list(Specs), N, Sink, Demand, OnPoison, Pids).

keeper_loop(P, Specs, N, Sink, Demand, OnPoison, Pids) ->
    receive
        stop ->
            [begin unlink(Pid), exit(Pid, kill) end || Pid <- maps:values(Pids)],
            ok;
        {'EXIT', Dead, _} ->
            case [I || {I, Pid} <- maps:to_list(Pids), Pid =:= Dead] of
                [I] ->
                    New = spawn_stage(P, I, N, maps:get(I, Specs), Sink, Demand, OnPoison),
                    keeper_loop(P, Specs, N, Sink, Demand, OnPoison, Pids#{I := New});
                [] -> keeper_loop(P, Specs, N, Sink, Demand, OnPoison, Pids)
            end;
        {pids, From} ->
            From ! {rakun_stream_pids, [maps:get(I, Pids) || I <- lists:seq(1, N)]},
            keeper_loop(P, Specs, N, Sink, Demand, OnPoison, Pids)
    end.

spawn_stage(P, I, N, {StageName, Step}, Sink, Demand, OnPoison) ->
    Me = self(),
    Pid = spawn_link(fun() ->
                             catch unregister(name(P, I)),
                             register(name(P, I), self()),
                             Me ! {rakun_stream_stage, self()},
                             stage_loop(#{p => P, i => I, n => N, stage => StageName, step => Step, sink => Sink,
                                          demand => Demand, poison => OnPoison, buf => queue:new()})
                     end),
    receive {rakun_stream_stage, Pid} -> ok after 2000 -> ok end,
    Pid.

%% Accepts offers while it holds fewer than Demand; then works one event.
stage_loop(S = #{buf := Buf, demand := D}) ->
    Held = queue:len(Buf),
    case Held of
        0 ->
            receive {offer, From, Ref, Item} -> accept(S, From, Ref, Item) end;
        _ when Held < D ->
            receive {offer, From, Ref, Item} -> accept(S, From, Ref, Item)
            after 0 -> work(S)
            end;
        _ -> work(S)
    end.

accept(S = #{buf := Buf, p := P, stage := Name}, From, Ref, Item) ->
    Buf2 = queue:in(Item, Buf),
    note_peak(P, Name, queue:len(Buf2)),
    From ! {Ref, accepted},
    stage_loop(S#{buf := Buf2}).

note_peak(P, Name, N) ->
    K = {P, Name},
    case ets:lookup(rakun_stream_peaks, K) of
        [{_, M}] when M >= N -> ok;
        _ -> ets:insert(rakun_stream_peaks, {K, N})
    end.

work(S = #{buf := Buf, step := Step, stage := Name, poison := OnPoison}) ->
    {{value, Item}, Rest} = queue:out(Buf),
    Outs = try Step(Item)
           catch _:{panic, R} when is_binary(R) -> _ = OnPoison(Name, Item, R), [];
                 _:R -> _ = OnPoison(Name, Item, iolist_to_binary(io_lib:format("~p", [R]))), []
           end,
    %% the in-hand event still counts against demand while its outputs move on
    S1 = S#{buf := queue:in_r(held, Rest)},
    [forward(S1, O) || O <- Outs],
    stage_loop(S1#{buf := Rest}).

forward(#{p := P, i := I, n := N, sink := Sink}, Out) ->
    case I =:= N of
        true -> _ = Sink(Out), ok;
        false -> offer(name(P, I + 1), Out)
    end.

offer(Name, Item) ->
    case whereis(Name) of
        undefined -> timer:sleep(5), offer(Name, Item);
        Pid ->
            Ref = erlang:monitor(process, Pid),
            Pid ! {offer, self(), Ref, Item},
            receive
                {Ref, accepted} -> erlang:demonitor(Ref, [flush]), ok;
                {'DOWN', Ref, _, _, _} -> timer:sleep(5), offer(Name, Item)
            end
    end.

%% A source hands an event to stage 1, blocking while stage 1 has no room.
push(P, Item) -> offer(name(P, 1), Item), 0.

stage_pids(P) ->
    case persistent_term:get({rakun_stream_keeper, P}, undefined) of
        undefined -> [];
        K -> K ! {pids, self()}, receive {rakun_stream_pids, L} -> [list_to_binary(pid_to_list(X)) || X <- L] after 2000 -> [] end
    end.

kill_stage(P, I) ->
    case whereis(name(P, I)) of
        undefined -> <<>>;
        Pid -> exit(Pid, kill), list_to_binary(pid_to_list(Pid))
    end.

peaks(P) -> [iolist_to_binary([N, "=", integer_to_binary(M)]) || {{P2, N}, M} <- ets:tab2list(rakun_stream_peaks), P2 =:= P].

collect(Name, Item) -> peaks_tab(), ets:insert(rakun_stream_collect, {Name, erlang:unique_integer([monotonic]), Item}), 0.

collected(Name) ->
    peaks_tab(),
    [I || {_, _, I} <- lists:keysort(2, [X || X = {N, _, _} <- ets:tab2list(rakun_stream_collect), N =:= Name])].

clear_collected(Name) -> peaks_tab(), ets:delete(rakun_stream_collect, Name), 0.
