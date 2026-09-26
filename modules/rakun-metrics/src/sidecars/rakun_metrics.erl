%%% rakun-metrics — the meter registry, the BEAM VM meters, the exposition
%%% renderers and the process diagnostics (front 75).
%%%
%%% THE REGISTRY. A meter is `{Name, TagKey}`: the tag list is renamed
%%% (`rakun.metrics.rename.<from>=<to>`), merged with the common tags
%%% (`rakun.metrics.tags.*`, resolved once by `install/0` — a key both carry
%%% refuses the registration) and sorted by key, so `[a, b]` and `[b, a]` are one
%%% series. `TagKey` is the sorted list encoded as `k=v,k=v`, and a handle
%%% carries it: incrementing a counter is ONE `ets:update_counter/3` in the
%%% calling process, no message and no re-sorting. A name a
%%% `rakun.metrics.enable.<prefix>=false` denies is never registered: its handle
%%% is `!denied` and every write through it is a no-op.
%%%
%%% Rows of `rakun_metrics_tab` (public, named, owned by `rakun_metrics_owner`):
%%%   {{meter, Name, TagKey}, Kind, Tags, Bounds}   Kind: counter|gauge|timer|summary
%%%   {{kind, Name}, Kind}
%%%   {{c, Name, TagKey}, Value}
%%%   {{g, Name, TagKey}, Fun}
%%%   {{t, Name, TagKey}, Count, Sum, B1 … Bn}      (a sample in the first bound ≥ it)
%%%   {{tmax, Name, TagKey}, Max}
%%% Timer values are microseconds; a distribution summary is the same row in
%%% its own unit. Bounds come from `rakun.metrics.distribution.slo.<name>`
%%% (sorted ascending), else the default set for a timer and none for a summary.
%%%
%%% THE RENDERERS iterate every series on every scrape, which is a tight loop
%%% over ETS — so they are Erlang: the Prometheus text exposition format, the
%%% StatsD lines and the OTLP/JSON bodies.

-module(rakun_metrics).
-export([ensure/0, reset/0, install/0, common_reload/0, validate_distribution/0,
         register/3, counter_inc/3, counter_value/2, gauge/3, timer_record/3,
         timer_stats/2, timed/3, meter_names/0, prometheus/1, snapshot/0,
         vm_install/0, vm_memory/0, queue_max/1, swt_enables/0, utilization/0,
         processes/2, vm_json/0, statsd_lines/0, statsd_send/3,
         span_add/2, span_count/0, span_take/0, span_buffered/0, span_cap/0,
         otlp_metrics_json/1, otlp_traces_json/2, otlp_start/2, otlp_stop/0, otlp_running/0,
         failure_note/1, failure_count/0, auto_install/0, now_micros/0, rand_unit/0,
         open_span_put/2, open_span_take/1, gauge_read/1, span_from_event/3, span_subscribe_once/0, sample/1]).

-define(T, rakun_metrics_tab).
-define(S, rakun_metrics_spans).   %% ordered_set: {Seq, SpanJson}
-define(OWNER, rakun_metrics_owner).
-define(DENIED, <<"!denied">>).
-define(SPAN_CAP, 2048).

%% ═══ lifecycle ═══════════════════════════════════════════════════════════════

ensure() ->
    case ets:whereis(?T) of
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
    case (try erlang:register(?OWNER, self()) catch error:badarg -> false end) of
        true ->
            _ = ets:new(?T, [named_table, public, set, {write_concurrency, true}, {read_concurrency, true}]),
            _ = ets:new(?S, [named_table, public, ordered_set]),
            Caller ! {?OWNER, ready},
            owner_loop(undefined);
        _ ->
            Caller ! {?OWNER, ready},
            ok
    end.

%% The owner also runs the OTLP pusher's timer, so a push outlives the process
%% that started it.
owner_loop(Push) ->
    receive
        {otlp_start, Step, Fun, From} ->
            cancel(Push),
            Ref = erlang:send_after(Step, self(), {otlp_tick, Step, Fun}),
            From ! {otlp_started, self()},
            owner_loop({Ref, Step, Fun});
        {otlp_stop, From} ->
            cancel(Push),
            From ! {otlp_stopped, self()},
            owner_loop(undefined);
        {otlp_running, From} ->
            From ! {otlp_running, Push =/= undefined},
            owner_loop(Push);
        {otlp_tick, Step, Fun} ->
            _ = spawn(fun() -> try Fun() catch _:_ -> ok end end),
            Ref = erlang:send_after(Step, self(), {otlp_tick, Step, Fun}),
            owner_loop({Ref, Step, Fun});
        _ -> owner_loop(Push)
    end.

cancel(undefined) -> ok;
cancel({Ref, _, _}) -> _ = erlang:cancel_timer(Ref), ok.

reset() ->
    ensure(),
    ets:delete_all_objects(?T),
    ets:delete_all_objects(?S),
    _ = persistent_term:erase(rakun_metrics_common),
    _ = persistent_term:erase(rakun_metrics_failures),
    _ = persistent_term:erase(rakun_metrics_spans_seen),
    0.

%% Boot: resolve the common tags once and refuse a bad distribution property.
install() ->
    ensure(),
    0 = validate_distribution(),
    common_reload(),
    0.

common_reload() ->
    Tags = [{rename(K), V} || {K, V} <- props_under(<<"rakun.metrics.tags.">>), V =/= <<>>],
    persistent_term:put(rakun_metrics_common, lists:ukeysort(1, Tags)),
    length(Tags).

common() ->
    case persistent_term:get(rakun_metrics_common, undefined) of
        undefined -> common_reload(), persistent_term:get(rakun_metrics_common);
        L -> L
    end.

%% ═══ registration ════════════════════════════════════════════════════════════

register(Kind0, Name, Tags0) ->
    ensure(),
    Kind = to_kind(Kind0),
    ok = check_name(Name),
    case denied(Name) of
        true -> ?DENIED;
        false ->
            Own = [{rename(to_bin(K)), to_bin(V)} || {K, V} <- Tags0],
            Common = common(),
            case [K || {K, _} <- Own, lists:keymember(K, 1, Common)] of
                [C | _] ->
                    erlang:error(<<"rakun metrics: the common tag `", C/binary, "` collides with the meter `",
                                   Name/binary, "`'s own tag `", C/binary, "` - rename one of them">>);
                [] -> ok
            end,
            Tags = lists:ukeysort(1, Own ++ Common),
            TagKey = encode_tags(Tags),
            case ets:insert_new(?T, {{kind, Name}, Kind}) of
                true -> ok;
                false ->
                    case ets:lookup_element(?T, {kind, Name}, 2) of
                        Kind -> ok;
                        Other ->
                            erlang:error(<<"rakun metrics: `", Name/binary, "` is already a ",
                                           (atom_to_binary(Other))/binary, " - one name, one meter kind">>)
                    end
            end,
            Bounds = bounds(Kind, Name),
            case ets:insert_new(?T, {{meter, Name, TagKey}, Kind, Tags, Bounds}) of
                true -> init_row(Kind, Name, TagKey, Bounds);
                false -> ok
            end,
            TagKey
    end.

to_kind(K) when is_atom(K) -> K;
to_kind(<<"counter">>) -> counter;
to_kind(<<"gauge">>) -> gauge;
to_kind(<<"timer">>) -> timer;
to_kind(<<"summary">>) -> summary.

init_row(counter, Name, TK, _) -> ets:insert_new(?T, {{c, Name, TK}, 0});
init_row(gauge, _, _, _) -> true;
init_row(_, Name, TK, Bounds) ->
    ets:insert_new(?T, list_to_tuple([{t, Name, TK}, 0, 0 | [0 || _ <- Bounds]])),
    ets:insert_new(?T, {{tmax, Name, TK}, 0}).

%% A name the exposition format can carry: a letter, then letters, digits,
%% `_` and `.` (a dot becomes `_` on the wire).
check_name(<<>>) -> erlang:error(<<"rakun metrics: a meter needs a name">>);
check_name(Name) ->
    case [C || <<C/utf8>> <= Name, not name_char(C)] of
        [] ->
            <<First, _/binary>> = Name,
            case (First >= $a andalso First =< $z) orelse (First >= $A andalso First =< $Z) of
                true -> ok;
                false -> erlang:error(<<"rakun metrics: the meter name `", Name/binary, "` must start with a letter">>)
            end;
        [Bad | _] ->
            erlang:error(<<"rakun metrics: the meter name `", Name/binary, "` contains `", Bad/utf8,
                           "`, which the exposition format cannot carry - use letters, digits, `_` and `.`">>)
    end.

name_char(C) ->
    (C >= $a andalso C =< $z) orelse (C >= $A andalso C =< $Z) orelse
        (C >= $0 andalso C =< $9) orelse C =:= $_ orelse C =:= $..

denied(Name) ->
    lists:any(fun({Prefix, V}) ->
                      V =:= <<"false">> andalso
                          (Name =:= Prefix orelse
                           binary:longest_common_prefix([Name, <<Prefix/binary, ".">>]) =:= byte_size(Prefix) + 1)
              end, props_under(<<"rakun.metrics.enable.">>)).

rename(K) ->
    case prop(<<"rakun.metrics.rename.", K/binary>>) of
        <<>> -> K;
        To -> To
    end.

encode_tags(Tags) ->
    iolist_to_binary(lists:join(<<",">>, [[K, <<"=">>, V] || {K, V} <- Tags])).

%% ═══ distribution ════════════════════════════════════════════════════════════

default_timer_bounds() ->
    [5000, 10000, 25000, 50000, 100000, 250000, 500000, 1000000, 2500000, 5000000, 10000000].

bounds(counter, _) -> [];
bounds(gauge, _) -> [];
bounds(Kind, Name) ->
    Unit = case Kind of timer -> micros; summary -> plain end,
    case prop(<<"rakun.metrics.distribution.slo.", Name/binary>>) of
        <<>> ->
            case {Kind, prop(<<"rakun.metrics.distribution.percentiles-histogram.", Name/binary>>)} of
                {timer, <<"false">>} -> [];
                {timer, _} -> default_timer_bounds();
                {summary, _} -> []
            end;
        Text -> parse_slo(Name, Text, Unit)
    end.

parse_slo(Name, Text, Unit) ->
    Parts = [string:trim(P) || P <- binary:split(Text, <<",">>, [global]), string:trim(P) =/= <<>>],
    lists:usort([parse_bound(Name, Text, P, Unit) || P <- Parts]).

parse_bound(Name, Text, P, Unit) ->
    case re:run(P, <<"^([0-9]+)(us|ms|s|m|h)?$">>, [{capture, all_but_first, binary}]) of
        {match, [N]} when Unit =:= plain -> binary_to_integer(N);
        {match, [N, U]} when Unit =:= micros ->
            binary_to_integer(N) * case U of
                                       <<"us">> -> 1;
                                       <<"ms">> -> 1000;
                                       <<"s">> -> 1000000;
                                       <<"m">> -> 60000000;
                                       <<"h">> -> 3600000000
                                   end;
        {match, [N, <<>>]} when Unit =:= micros -> binary_to_integer(N) * 1000;
        _ ->
            erlang:error(<<"rakun metrics: rakun.metrics.distribution.slo.", Name/binary, " = `", Text/binary,
                           "`: `", P/binary, "` is not a duration (100ms, 1s, 250us)">>)
    end.

%% Every SLO property parses, or the boot is refused naming it.
validate_distribution() ->
    lists:foreach(fun({Name, Text}) -> _ = parse_slo(Name, Text, micros) end,
                  [{N, V} || {N, V} <- props_under(<<"rakun.metrics.distribution.slo.">>), V =/= <<>>,
                             ets:lookup(?T, {kind, N}) =/= [{{kind, N}, summary}]]),
    0.

%% ═══ writing ═════════════════════════════════════════════════════════════════

counter_inc(_Name, ?DENIED, _D) -> 0;
counter_inc(Name, TK, D) ->
    ets:update_counter(?T, {c, Name, TK}, D).

counter_value(_Name, ?DENIED) -> 0;
counter_value(Name, TK) ->
    case ets:lookup(?T, {c, Name, TK}) of
        [{_, V}] -> V;
        [] -> 0
    end.

gauge(Name, Tags, Fun) ->
    case register(gauge, Name, Tags) of
        ?DENIED -> 0;
        TK -> _ = ets:insert_new(?T, {{g, Name, TK}, Fun}), 1
    end.

timer_record(_Name, ?DENIED, _V) -> 0;
timer_record(Name, TK, V) ->
    Bounds = ets:lookup_element(?T, {meter, Name, TK}, 4),
    Ops = case slot(V, Bounds, 4) of
              none -> [{2, 1}, {3, V}];
              Pos -> [{2, 1}, {3, V}, {Pos, 1}]
          end,
    _ = ets:update_counter(?T, {t, Name, TK}, Ops),
    bump_max({tmax, Name, TK}, V),
    0.

slot(_V, [], _Pos) -> none;
slot(V, [B | _], Pos) when V =< B -> Pos;
slot(V, [_ | Rest], Pos) -> slot(V, Rest, Pos + 1).

bump_max(Key, V) ->
    case ets:lookup_element(?T, Key, 2) of
        M when M >= V -> ok;
        _ ->
            case ets:select_replace(?T, [{{Key, '$1'}, [{'<', '$1', V}], [{{{const, Key}, V}}]}]) of
                1 -> ok;
                0 -> bump_max(Key, V)
            end
    end.

%% `count\ttotal\tmax` for a timer or summary.
timer_stats(_Name, ?DENIED) -> <<"0\t0\t0">>;
timer_stats(Name, TK) ->
    case ets:lookup(?T, {t, Name, TK}) of
        [Row] ->
            Max = ets:lookup_element(?T, {tmax, Name, TK}, 2),
            iolist_to_binary([integer_to_binary(element(2, Row)), "\t", integer_to_binary(element(3, Row)),
                              "\t", integer_to_binary(Max)]);
        [] -> <<"0\t0\t0">>
    end.

%% Times `Fun`, recording under `outcome=ok` or `outcome=error`; a raise is
%% re-raised after the sample is recorded.
timed(Name, Tags, Fun) ->
    T0 = erlang:monotonic_time(microsecond),
    try Fun() of
        V -> record_outcome(Name, Tags, <<"ok">>, T0), V
    catch C:R:S ->
        record_outcome(Name, Tags, <<"error">>, T0),
        erlang:raise(C, R, S)
    end.

record_outcome(Name, Tags, Outcome, T0) ->
    TK = register(timer, Name, [{<<"outcome">>, Outcome} | [{to_bin(K), to_bin(V)} || {K, V} <- Tags]]),
    timer_record(Name, TK, erlang:monotonic_time(microsecond) - T0).

meter_names() ->
    ensure(),
    lists:usort([N || {{kind, N}, _} <- ets:tab2list(?T)]).

%% Every series as a term, for a remote shell (`erl -remsh`).
snapshot() ->
    ensure(),
    [{N, Tags, Kind, value_of(Kind, N, TK)} || {{meter, N, TK}, Kind, Tags, _} <- lists:sort(ets:tab2list(?T))].

value_of(counter, N, TK) -> counter_value(N, TK);
value_of(gauge, N, TK) -> gauge_value(N, TK);
value_of(_, N, TK) -> timer_stats(N, TK).

%% The first series of gauge `Name`, or -1.
gauge_read(Name) ->
    ensure(),
    case [TK || {{meter, N, TK}, gauge, _, _} <- ets:tab2list(?T), N =:= Name] of
        [TK | _] -> case gauge_value(Name, TK) of undefined -> -1; V when is_float(V) -> round(V * 1000); V -> V end;
        [] -> -1
    end.

gauge_value(N, TK) ->
    case ets:lookup(?T, {g, N, TK}) of
        [{_, F}] -> try F() of V when is_number(V) -> V; _ -> undefined catch _:_ -> undefined end;
        [] -> undefined
    end.

%% ═══ Prometheus text exposition ══════════════════════════════════════════════
%% Families sorted by name; a family's samples sorted by tag key. A gauge
%% whose function raises or answers a non-number is left out of that scrape.

prometheus(Prefix) ->
    ensure(),
    Metas = lists:sort([{N, TK, Kind, Tags, B} || {{meter, N, TK}, Kind, Tags, B} <- ets:tab2list(?T),
                                                  has_prefix(N, Prefix)]),
    iolist_to_binary(families(Metas, undefined)).

has_prefix(_N, <<>>) -> true;
has_prefix(N, P) -> binary:longest_common_prefix([N, P]) =:= byte_size(P).

families([], _) -> [];
families([{N, TK, Kind, Tags, B} | Rest], Last) ->
    Head = case N =:= Last of
               true -> [];
               false -> type_line(Kind, N)
           end,
    [Head, samples(Kind, N, TK, Tags, B) | families(Rest, N)].

wire(N) -> binary:replace(N, <<".">>, <<"_">>, [global]).

type_line(counter, N) -> ["# TYPE ", wire(N), "_total counter\n"];
type_line(gauge, N) -> ["# TYPE ", wire(N), " gauge\n"];
type_line(timer, N) -> ["# TYPE ", wire(N), "_seconds histogram\n"];
type_line(summary, N) -> ["# TYPE ", wire(N), " histogram\n"].

samples(counter, N, TK, Tags, _) ->
    [wire(N), "_total", labels(Tags, []), " ", integer_to_binary(counter_value(N, TK)), "\n"];
samples(gauge, N, TK, Tags, _) ->
    case gauge_value(N, TK) of
        undefined -> [];
        V -> [wire(N), labels(Tags, []), " ", num(V), "\n"]
    end;
samples(Kind, N, TK, Tags, Bounds) ->
    case ets:lookup(?T, {t, N, TK}) of
        [] -> [];
        [Row] ->
            Count = element(2, Row),
            Sum = element(3, Row),
            Counts = [element(I, Row) || I <- lists:seq(4, 3 + length(Bounds))],
            Base = case Kind of timer -> [wire(N), "_seconds"]; summary -> wire(N) end,
            Fmt = case Kind of timer -> fun secs/1; summary -> fun integer_to_binary/1 end,
            {Lines, _} = lists:mapfoldl(
                           fun({B, C}, Acc) ->
                                   Cum = Acc + C,
                                   {[Base, "_bucket", labels(Tags, [{<<"le">>, Fmt(B)}]), " ",
                                     integer_to_binary(Cum), "\n"], Cum}
                           end, 0, lists:zip(Bounds, Counts)),
            [Lines,
             Base, "_bucket", labels(Tags, [{<<"le">>, <<"+Inf">>}]), " ", integer_to_binary(Count), "\n",
             Base, "_count", labels(Tags, []), " ", integer_to_binary(Count), "\n",
             Base, "_sum", labels(Tags, []), " ", Fmt(Sum), "\n"]
    end.

labels([], []) -> [];
labels(Tags, Extra) ->
    ["{", lists:join(",", [[K, "=\"", escape(V), "\""] || {K, V} <- Tags ++ Extra]), "}"].

escape(V) ->
    << <<(esc(C))/binary>> || <<C>> <= V >>.

esc($\\) -> <<"\\\\">>;
esc($") -> <<"\\\"">>;
esc($\n) -> <<"\\n">>;
esc(C) -> <<C>>.

secs(Micros) -> float_to_binary(Micros / 1000000, [short]).

num(V) when is_integer(V) -> integer_to_binary(V);
num(V) when is_float(V) -> float_to_binary(V, [short]).

%% ═══ BEAM VM meters ══════════════════════════════════════════════════════════

vm_install() ->
    ensure(),
    G = fun(Name, F) -> gauge(Name, [], F) end,
    G(<<"beam.schedulers.run_queue">>, fun() -> erlang:statistics(total_run_queue_lengths) end),
    G(<<"beam.processes.count">>, fun() -> erlang:system_info(process_count) end),
    G(<<"beam.processes.limit">>, fun() -> erlang:system_info(process_limit) end),
    G(<<"beam.ports.count">>, fun() -> erlang:system_info(port_count) end),
    G(<<"beam.ports.limit">>, fun() -> erlang:system_info(port_limit) end),
    G(<<"beam.atoms.count">>, fun() -> erlang:system_info(atom_count) end),
    G(<<"beam.atoms.limit">>, fun() -> erlang:system_info(atom_limit) end),
    lists:foreach(fun(Area) ->
                          G(<<"beam.memory.", (atom_to_binary(Area))/binary>>, fun() -> erlang:memory(Area) end)
                  end, [total, processes, system, atom, binary, code, ets]),
    G(<<"beam.gc.count">>, fun() -> element(1, erlang:statistics(garbage_collection)) end),
    G(<<"beam.gc.words_reclaimed">>, fun() -> element(2, erlang:statistics(garbage_collection)) end),
    G(<<"beam.messages.queue_max">>, fun() -> queue_max(budget()) end),
    case prop(<<"rakun.metrics.beam.scheduler-utilization">>) of
        <<"true">> ->
            enable_swt(),
            G(<<"beam.schedulers.utilization">>, fun() -> utilization() end);
        _ -> ok
    end,
    0.

budget() ->
    case prop(<<"rakun.metrics.beam.queue-sample-budget">>) of
        <<>> -> 20;
        B -> binary_to_integer(B)
    end.

%% `scheduler_wall_time` is off by default and costs a little: turned on once.
enable_swt() ->
    case persistent_term:get(rakun_metrics_swt, 0) of
        0 ->
            _ = erlang:system_flag(scheduler_wall_time, true),
            persistent_term:put(rakun_metrics_swt, 1);
        _ -> ok
    end.

swt_enables() -> persistent_term:get(rakun_metrics_swt, 0).

%% The share of wall time the schedulers were busy since the previous sample.
utilization() ->
    Now = lists:sort(erlang:statistics(scheduler_wall_time)),
    Prev = persistent_term:get(rakun_metrics_swt_prev, undefined),
    persistent_term:put(rakun_metrics_swt_prev, Now),
    case Prev of
        undefined -> 0.0;
        _ ->
            {A, T} = lists:foldl(fun({{I, A1, T1}, {I, A0, T0}}, {AA, TT}) -> {AA + (A1 - A0), TT + (T1 - T0)};
                                    (_, Acc) -> Acc
                                 end, {0, 0}, lists:zip(Now, Prev)),
            case T of 0 -> 0.0; _ -> A / T end
    end.

%% The longest mailbox among the processes visited before `BudgetMs` ran out.
queue_max(BudgetMs) ->
    Deadline = erlang:monotonic_time(millisecond) + BudgetMs,
    queue_walk(erlang:processes(), Deadline, 0, 0).

queue_walk([], _D, _N, Max) -> Max;
queue_walk([P | Rest], D, N, Max) ->
    Over = (N band 255) =:= 0 andalso erlang:monotonic_time(millisecond) > D,
    case Over of
        true -> Max;
        false ->
            Len = case erlang:process_info(P, message_queue_len) of
                      {message_queue_len, L} -> L;
                      undefined -> 0
                  end,
            queue_walk(Rest, D, N + 1, max(Max, Len))
    end.

vm_memory() ->
    iolist_to_binary(json:encode(maps:from_list(erlang:memory()))).

vm_json() ->
    Mem = maps:from_list(erlang:memory()),
    iolist_to_binary(json:encode(#{memory => Mem,
                                   processes => erlang:system_info(process_count),
                                   ports => erlang:system_info(port_count),
                                   atoms => erlang:system_info(atom_count),
                                   schedulers => erlang:system_info(schedulers_online),
                                   allocators => [atom_to_binary(A) || A <- erlang:system_info(alloc_util_allocators)]})).

%% ═══ process diagnostics ═════════════════════════════════════════════════════
%% Asks each process for the seven keys it reports — never the whole-info form,
%% which copies a large heap's worth of terms per process.

processes(Sort, Limit) ->
    Keys = [registered_name, initial_call, current_function, reductions, memory, message_queue_len, stack_size],
    SortKey = binary_to_existing_atom(Sort),
    Rows = [{P, maps:from_list(I)} || P <- erlang:processes(), I <- [erlang:process_info(P, Keys)], I =/= undefined],
    Sorted = lists:sublist(lists:sort(fun({_, A}, {_, B}) -> maps:get(SortKey, A) >= maps:get(SortKey, B) end, Rows),
                           Limit),
    iolist_to_binary(json:encode([row(P, I) || {P, I} <- Sorted])).

row(P, I) ->
    #{pid => list_to_binary(pid_to_list(P)),
      registered_name => case maps:get(registered_name, I) of [] -> <<>>; N -> atom_to_binary(N) end,
      initial_call => mfa(maps:get(initial_call, I)),
      current_function => mfa(maps:get(current_function, I)),
      reductions => maps:get(reductions, I),
      memory => maps:get(memory, I),
      message_queue_len => maps:get(message_queue_len, I),
      stack_size => maps:get(stack_size, I)}.

mfa({M, F, A}) -> iolist_to_binary(io_lib:format("~p:~p/~p", [M, F, A]));
mfa(_) -> <<>>.

%% ═══ StatsD ══════════════════════════════════════════════════════════════════
%% One line per series: a counter's increase since the previous push (`|c`), a
%% gauge's value (`|g`), a timer's count increase (`.count|c`) and its total in
%% milliseconds (`.sum|ms`); tags in the DogStatsD `|#k:v` form.

statsd_lines() ->
    ensure(),
    Metas = lists:sort([{N, TK, Kind, Tags} || {{meter, N, TK}, Kind, Tags, _} <- ets:tab2list(?T)]),
    iolist_to_binary(lists:join(<<"\n">>, lists:append([statsd(M) || M <- Metas]))).

statsd({N, TK, counter, Tags}) ->
    V = counter_value(N, TK),
    D = V - last({sc, N, TK}, V),
    [iolist_to_binary([N, ":", integer_to_binary(D), "|c", dtags(Tags)])];
statsd({N, TK, gauge, Tags}) ->
    case gauge_value(N, TK) of
        undefined -> [];
        V -> [iolist_to_binary([N, ":", num(V), "|g", dtags(Tags)])]
    end;
statsd({N, TK, _, Tags}) ->
    case ets:lookup(?T, {t, N, TK}) of
        [Row] ->
            C = element(2, Row), S = element(3, Row),
            DC = C - last({stc, N, TK}, C), DS = S - last({sts, N, TK}, S),
            [iolist_to_binary([N, ".count:", integer_to_binary(DC), "|c", dtags(Tags)]),
             iolist_to_binary([N, ".sum:", integer_to_binary(DS div 1000), "|ms", dtags(Tags)])];
        [] -> []
    end.

last(Key, Now) ->
    Prev = case ets:lookup(?T, Key) of [{_, P}] -> P; [] -> 0 end,
    ets:insert(?T, {Key, Now}),
    Prev.

dtags([]) -> [];
dtags(Tags) -> ["|#", lists:join(",", [[K, ":", V] || {K, V} <- Tags])].

%% Fire and forget: any failure — no route, a closed port, a bad host — is
%% swallowed and answered as 0 sent.
statsd_send(Host, Port, Payload) ->
    try
        {ok, S} = gen_udp:open(0, [binary]),
        R = gen_udp:send(S, binary_to_list(Host), Port, Payload),
        gen_udp:close(S),
        case R of ok -> 1; _ -> 0 end
    catch _:_ -> 0
    end.

%% ═══ spans for export ════════════════════════════════════════════════════════
%% A bounded buffer: past the cap the oldest span is dropped, so an unreachable
%% collector costs a fixed amount of memory.

span_add(SpanJson, _Name) ->
    ensure(),
    ets:insert(?S, {erlang:unique_integer([monotonic, positive]), SpanJson}),
    persistent_term:put(rakun_metrics_spans_seen, persistent_term:get(rakun_metrics_spans_seen, 0) + 1),
    trim(ets:info(?S, size) - ?SPAN_CAP),
    0.

trim(N) when N =< 0 -> ok;
trim(N) ->
    ets:delete(?S, ets:first(?S)),
    trim(N - 1).

span_count() -> persistent_term:get(rakun_metrics_spans_seen, 0).
span_buffered() -> ensure(), ets:info(?S, size).
span_cap() -> ?SPAN_CAP.

%% The buffered spans (a JSON array of span objects), removing them.
span_take() ->
    ensure(),
    Rows = ets:tab2list(?S),
    lists:foreach(fun({K, _}) -> ets:delete(?S, K) end, Rows),
    iolist_to_binary(["[", lists:join(",", [J || {_, J} <- Rows]), "]"]).

open_span_put(Id, Span) -> put({rakun_metrics_span, Id}, Span), 0.

%% True the first time only: the span subscriber is attached once per node.
span_subscribe_once() ->
    case persistent_term:get(rakun_metrics_span_sub, false) of
        true -> false;
        false -> persistent_term:put(rakun_metrics_span_sub, true), true
    end.

%% The draw against a probability written as text (`0.1`, `1`, `0`).
sample(Text) ->
    P = try binary_to_float(Text)
        catch _:_ -> try float(binary_to_integer(Text)) catch _:_ -> 0.1 end
        end,
    P >= 1.0 orelse (P > 0.0 andalso rand:uniform() < P).

%% A span's stop event, in the process that ended it: buffered as an OTLP span
%% when the trace is sampled (flag `01`).
span_from_event(Event, MJson, DJson) ->
    Stop = binary:longest_common_prefix([binary_reverse(Event), <<"pots.">>]) =:= 5,
    Sampled = get(rakun_trace_flags) =/= <<"00">>,
    case Stop andalso Sampled of
        false -> 0;
        true ->
            M = try json:decode(MJson) catch _:_ -> #{} end,
            D = try json:decode(DJson) catch _:_ -> #{} end,
            Name = maps:get(<<"name">>, D, <<>>),
            End = maps:get(<<"system_time">>, M, 0),
            Dur = maps:get(<<"duration">>, M, 0),
            Attr = try json:decode(maps:get(<<"attributes">>, D, <<"{}">>)) catch _:_ -> #{} end,
            Kind = case Name of
                       <<"http.server.request">> -> 2;
                       <<"http.client.request">> -> 3;
                       _ -> 1
                   end,
            Span = #{traceId => maps:get(<<"trace_id">>, D, <<>>), spanId => maps:get(<<"span_id">>, D, <<>>),
                     parentSpanId => maps:get(<<"parent_id">>, D, <<>>), name => Name, kind => Kind,
                     startTimeUnixNano => integer_to_binary((End - Dur) * 1000),
                     endTimeUnixNano => integer_to_binary(End * 1000),
                     attributes => [#{key => K, value => #{stringValue => to_bin(V)}} || {K, V} <- maps:to_list(Attr)],
                     status => #{message => to_bin(maps:get(<<"outcome">>, D, <<>>))}},
            span_add(iolist_to_binary(json:encode(Span)), Name)
    end.

binary_reverse(B) -> list_to_binary(lists:reverse(binary_to_list(B))).
open_span_take(Id) -> erase({rakun_metrics_span, Id}).

%% ═══ OTLP/JSON ═══════════════════════════════════════════════════════════════

resource(Service) ->
    #{attributes => [#{key => <<"service.name">>, value => #{stringValue => Service}}]}.

attrs(Tags) -> [#{key => K, value => #{stringValue => V}} || {K, V} <- Tags].

otlp_metrics_json(Service) ->
    ensure(),
    Now = integer_to_binary(erlang:system_time(nanosecond)),
    Metas = lists:sort([{N, TK, Kind, Tags, B} || {{meter, N, TK}, Kind, Tags, B} <- ets:tab2list(?T)]),
    Metrics = lists:append([otlp_metric(M, Now) || M <- Metas]),
    iolist_to_binary(json:encode(
      #{resourceMetrics => [#{resource => resource(Service),
                              scopeMetrics => [#{scope => #{name => <<"rakun-metrics">>}, metrics => Metrics}]}]})).

otlp_metric({N, TK, counter, Tags, _}, Now) ->
    [#{name => N, sum => #{aggregationTemporality => 2, isMonotonic => true,
                           dataPoints => [#{attributes => attrs(Tags), timeUnixNano => Now,
                                            asInt => integer_to_binary(counter_value(N, TK))}]}}];
otlp_metric({N, TK, gauge, Tags, _}, Now) ->
    case gauge_value(N, TK) of
        undefined -> [];
        V when is_integer(V) ->
            [#{name => N, gauge => #{dataPoints => [#{attributes => attrs(Tags), timeUnixNano => Now,
                                                      asInt => integer_to_binary(V)}]}}];
        V -> [#{name => N, gauge => #{dataPoints => [#{attributes => attrs(Tags), timeUnixNano => Now,
                                                       asDouble => V}]}}]
    end;
otlp_metric({N, TK, _, Tags, Bounds}, Now) ->
    case ets:lookup(?T, {t, N, TK}) of
        [Row] ->
            Counts = [element(I, Row) || I <- lists:seq(4, 3 + length(Bounds))],
            Over = element(2, Row) - lists:sum(Counts),
            [#{name => N, histogram =>
                   #{aggregationTemporality => 2,
                     dataPoints => [#{attributes => attrs(Tags), timeUnixNano => Now,
                                      count => integer_to_binary(element(2, Row)), sum => element(3, Row),
                                      explicitBounds => Bounds,
                                      bucketCounts => [integer_to_binary(C) || C <- Counts ++ [Over]]}]}}];
        [] -> []
    end.

otlp_traces_json(Service, SpansJsonArray) ->
    iolist_to_binary(["{\"resourceSpans\":[{\"resource\":", json:encode(resource(Service)),
                      ",\"scopeSpans\":[{\"scope\":{\"name\":\"rakun-metrics\"},\"spans\":", SpansJsonArray,
                      "}]}]}"]).

%% Starts (or restarts) the pusher: `Fun()` every `Step` ms, in a fresh process
%% each tick. A step of 0 stops it.
otlp_start(0, _Fun) -> otlp_stop();
otlp_start(Step, Fun) ->
    ensure(),
    whereis(?OWNER) ! {otlp_start, Step, Fun, self()},
    receive {otlp_started, _} -> 1 after 2000 -> 0 end.

otlp_stop() ->
    ensure(),
    whereis(?OWNER) ! {otlp_stop, self()},
    receive {otlp_stopped, _} -> 0 after 2000 -> 0 end.

otlp_running() ->
    ensure(),
    whereis(?OWNER) ! {otlp_running, self()},
    receive {otlp_running, R} -> R after 2000 -> false end.

failure_note(Text) ->
    persistent_term:put(rakun_metrics_failures, persistent_term:get(rakun_metrics_failures, 0) + 1),
    logger:warning("rakun metrics: export failed: ~ts", [Text]),
    0.

failure_count() -> persistent_term:get(rakun_metrics_failures, 0).

%% ═══ automatic meters ════════════════════════════════════════════════════════
%% Each owning front executes an event on `rakun_telemetry`; these handlers turn
%% the stop events into meters. A front that emits nothing produces no series.

auto_install() ->
    ensure(),
    A = fun(Id, Event, F) -> _ = rakun_telemetry:detach(Id), rakun_telemetry:attach(Id, Event, F, #{}) end,
    A(<<"rakun-metrics.http.server">>, [rakun, http, request, stop],
      fun(_E, M, D, _) ->
              TK = register(timer, <<"http.server.requests">>,
                            [{<<"method">>, to_bin(maps:get(method, D, <<>>))},
                             {<<"route">>, to_bin(maps:get(route, D, <<>>))},
                             {<<"status">>, to_bin(maps:get(status, D, <<>>))}]),
              timer_record(<<"http.server.requests">>, TK, maps:get(duration, M, 0))
      end),
    A(<<"rakun-metrics.http.client">>, [rakun, http, client, stop],
      fun(_E, M, D, _) ->
              Attr = try json:decode(maps:get(attributes, D, <<"{}">>)) catch _:_ -> #{} end,
              Url = maps:get(<<"url.full">>, Attr, <<>>),
              Host = case uri_string:parse(Url) of #{host := H} -> H; _ -> <<>> end,
              TK = register(timer, <<"http.client.requests">>,
                            [{<<"method">>, maps:get(<<"http.request.method">>, Attr, <<>>)},
                             {<<"host">>, to_bin(Host)},
                             {<<"status">>, to_bin(maps:get(outcome, D, <<>>))}]),
              timer_record(<<"http.client.requests">>, TK, maps:get(duration, M, 0))
      end),
    lists:foreach(
      fun({Op, Meter}) ->
              A(<<"rakun-metrics.cache.", (atom_to_binary(Op))/binary>>, [rakun, cache, Op, stop],
                fun(_E, _M, D, _) ->
                        TK = register(counter, Meter, [{<<"cache">>, to_bin(maps:get(cache, D, <<>>))},
                                                       {<<"result">>, to_bin(maps:get(result, D, <<>>))}]),
                        counter_inc(Meter, TK, 1)
                end)
      end, [{get, <<"cache.gets">>}, {put, <<"cache.puts">>}, {evict, <<"cache.evictions">>}]),
    lists:foreach(
      fun({Op, Meter}) ->
              A(<<"rakun-metrics.messaging.", (atom_to_binary(Op))/binary>>, [rakun, messaging, Op, stop],
                fun(_E, _M, D, _) ->
                        TK = register(counter, Meter, [{<<"broker">>, to_bin(maps:get(broker, D, <<>>))},
                                                       {<<"destination">>, to_bin(maps:get(destination, D, <<>>))}]),
                        counter_inc(Meter, TK, 1)
                end)
      end, [{consume, <<"messaging.consumed">>}, {publish, <<"messaging.published">>}]),
    0.

%% ═══ helpers ═════════════════════════════════════════════════════════════════

now_micros() -> erlang:system_time(microsecond).

rand_unit() -> rand:uniform().

prop(Key) ->
    case erlang:function_exported(rakun_runtime, prop, 1) of
        true -> rakun_runtime:prop(Key);
        false -> <<>>
    end.

%% `[{Rest, Value}]` for every property whose key starts with `Prefix`.
props_under(Prefix) ->
    _ = case erlang:function_exported(rakun_runtime, ensure_started, 0) of
            true -> rakun_runtime:ensure_started();
            false -> ok
        end,
    N = byte_size(Prefix),
    case ets:whereis(rakun_props) of
        undefined -> [];
        _ -> [{binary:part(K, N, byte_size(K) - N), V} || {K, V} <- ets:tab2list(rakun_props), is_binary(K),
                                                          byte_size(K) > N,
                                                          binary:longest_common_prefix([K, Prefix]) =:= N]
    end.

to_bin(B) when is_binary(B) -> B;
to_bin(I) when is_integer(I) -> integer_to_binary(I);
to_bin(A) when is_atom(A) -> atom_to_binary(A);
to_bin(L) when is_list(L) -> unicode:characters_to_binary(L);
to_bin(T) -> iolist_to_binary(io_lib:format("~p", [T])).
