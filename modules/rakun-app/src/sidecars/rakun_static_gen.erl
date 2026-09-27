%%% rakun-app — static generation, the BEAM half of front 60.
%%%
%%% WHAT LIVES HERE AND WHY. Only what botopink cannot hold or reach:
%%%
%%%   * the SEGMENT CONFIG and STATIC PARAMS registries (a config is a
%%%     botopink record, a producer a function value — stored opaque), and the
%%%     kind decided for each pattern at the last prerender;
%%%   * the bounded FAN-OUT: `run_bounded(N, Thunks)` runs unstarted thunks in
%%%     at most N processes at once and answers their results by index (an
%%%     `@Task` is eager on the BEAM, so only an unstarted thunk can run
%%%     concurrently);
%%%   * the SINGLE FLIGHT of a regeneration: one process per stale path,
%%%     claimed with `ets:insert_new/2`, so fifty concurrent requests start one;
%%%   * counters, a high-water gauge and a failure log the tests read.
%%%
%%% WHAT DOES NOT LIVE HERE. The decision, the path expansion, the entry, the
%%% staleness rule, the export's layout and every refusal text are botopink.
%%%
%%% MODULE ATOM. `rakun_static_gen`, never `static_gen` (the member emits one).
-module(rakun_static_gen).

-export([config_put/2, config_get/1, configs/0, params_put/2, params_get/1, params_patterns/0,
         kind_put/3, kinds/0, reset/0,
         run_bounded/2, regenerate/2, regenerating/0, drain/0,
         bump/1, count/1, gauge_enter/1, gauge_exit/1, gauge_max/1,
         log/1, logged/0, wide/1, schedulers/0, ensure_dir/1, now_ms/0]).

-define(T, rakun_static_gen_table).

config_put(Pattern, Config) ->
    ensure(),
    case ets:insert_new(?T, {{config, Pattern}, Config}) of
        true -> 1;
        false -> 0
    end.

config_get(Pattern) ->
    ensure(),
    case ets:lookup(?T, {config, Pattern}) of
        [{_, C}] -> C;
        [] -> undefined
    end.

configs() ->
    ensure(),
    lists:sort([P || {{config, P}, _} <- ets:tab2list(?T)]).

params_put(Pattern, Produce) ->
    ensure(),
    case ets:insert_new(?T, {{params, Pattern}, Produce}) of
        true -> 1;
        false -> 0
    end.

params_get(Pattern) ->
    ensure(),
    case ets:lookup(?T, {params, Pattern}) of
        [{_, F}] -> F;
        [] -> undefined
    end.

params_patterns() ->
    ensure(),
    lists:sort([P || {{params, P}, _} <- ets:tab2list(?T)]).

kind_put(Pattern, Kind, Reason) ->
    ensure(),
    true = ets:insert(?T, {{kind, Pattern}, Kind, Reason}),
    0.

%% `pattern|S|reason` / `pattern|D|reason`, sorted by pattern.
kinds() ->
    ensure(),
    lists:sort([iolist_to_binary([P, "|", K, "|", R]) || {{kind, P}, K, R} <- ets:tab2list(?T)]).

%% Forgets the registries, the decided kinds and the gauge's high-water mark.
%% A regeneration's claim, the counters, the live gauge and the log survive:
%% another test file running in the same node must not be able to free a
%% claim a worker still holds.
reset() ->
    ensure(),
    _ = ets:select_delete(?T, [{{{config, '_'}, '_'}, [], [true]},
                               {{{params, '_'}, '_'}, [], [true]},
                               {{{kind, '_'}, '_', '_'}, [], [true]},
                               {{{gauge_max, '_'}, '_'}, [], [true]}]),
    0.

%% ═══ the bounded fan-out ═════════════════════════════════════════════════════

%% Each result is the thunk's value (a string), or `raised|<reason>`.
run_bounded(N, Thunks) ->
    Indexed = lists:zip(lists:seq(1, length(Thunks)), Thunks),
    Results = bounded(max(1, N), Indexed, 0, #{}),
    [case maps:get(I, Results) of
         {ok, V} -> V;
         {raised, T} -> <<"raised|", T/binary>>
     end || I <- lists:seq(1, length(Thunks))].

bounded(_N, [], 0, Acc) -> Acc;
bounded(N, [{I, F} | Rest], Running, Acc) when Running < N ->
    Me = self(),
    _ = spawn(fun() ->
                      R = try {ok, F()} catch C:E -> {raised, iolist_to_binary(io_lib:format("~p:~p", [C, E]))} end,
                      Me ! {rakun_static_gen_done, I, R}
              end),
    bounded(N, Rest, Running + 1, Acc);
bounded(N, Queue, Running, Acc) ->
    receive
        {rakun_static_gen_done, I, R} -> bounded(N, Queue, Running - 1, Acc#{I => R})
    end.

%% ═══ single-flight regeneration ══════════════════════════════════════════════

regenerate(Path, Work) ->
    ensure(),
    case ets:insert_new(?T, {{regen, Path}, true}) of
        false -> 0;
        true ->
            _ = spawn(fun() ->
                              try Work() catch C:E -> log(iolist_to_binary(io_lib:format("~s: ~p:~p", [Path, C, E]))) end,
                              ets:delete(?T, {regen, Path})
                      end),
            1
    end.

regenerating() ->
    ensure(),
    length([P || {{regen, P}, _} <- ets:tab2list(?T)]).

drain() -> drain(300).
drain(0) -> regenerating();
drain(K) ->
    case regenerating() of
        0 -> 0;
        _ -> receive after 20 -> drain(K - 1) end
    end.

%% ═══ counters, the gauge and the log ═════════════════════════════════════════

bump(Key) ->
    ensure(),
    ets:update_counter(?T, {count, Key}, {2, 1}, {{count, Key}, 0}).

count(Key) ->
    ensure(),
    case ets:lookup(?T, {count, Key}) of
        [{_, N}] -> N;
        [] -> 0
    end.

gauge_enter(Key) ->
    ensure(),
    Now = ets:update_counter(?T, {gauge, Key}, {2, 1}, {{gauge, Key}, 0}),
    Max = case ets:lookup(?T, {gauge_max, Key}) of [{_, M}] -> M; [] -> 0 end,
    case Now > Max of
        true -> true = ets:insert(?T, {{gauge_max, Key}, Now});
        false -> ok
    end,
    Now.

gauge_exit(Key) ->
    ensure(),
    ets:update_counter(?T, {gauge, Key}, {2, -1}, {{gauge, Key}, 0}).

gauge_max(Key) ->
    ensure(),
    case ets:lookup(?T, {gauge_max, Key}) of [{_, M}] -> M; [] -> 0 end.

log(Line) ->
    ensure(),
    true = ets:insert(?T, {{log, erlang:unique_integer([monotonic, positive])}, Line}),
    io:put_chars(standard_error, ["rakun static: regeneration failed: ", Line, "\n"]),
    0.

logged() ->
    ensure(),
    [L || {{log, _}, L} <- lists:sort(ets:tab2list(?T))].

wide(N) -> N.

schedulers() -> erlang:system_info(schedulers_online).

%% Creates every missing directory above `File`.
ensure_dir(File) ->
    case filelib:ensure_dir(File) of
        ok -> 0;
        {error, R} -> erlang:error({rakun_static, iolist_to_binary(io_lib:format("cannot create the directory of ~s: ~p", [File, R]))})
    end.

now_ms() -> erlang:system_time(millisecond).

ensure() ->
    case ets:whereis(?T) of
        undefined ->
            Caller = self(),
            Pid = spawn(fun() ->
                                case (try erlang:register(rakun_static_gen_owner, self()) catch error:badarg -> false end) of
                                    true ->
                                        _ = ets:new(?T, [named_table, public, set]),
                                        Caller ! {rakun_static_gen_owner, ready},
                                        receive stop -> ok end;
                                    _ -> Caller ! {rakun_static_gen_owner, ready}
                                end
                        end),
            Ref = erlang:monitor(process, Pid),
            receive
                {rakun_static_gen_owner, ready} -> erlang:demonitor(Ref, [flush]), ok;
                {'DOWN', Ref, process, Pid, _} -> ok
            after 5000 -> erlang:demonitor(Ref, [flush]), ok
            end;
        _ -> ok
    end.
