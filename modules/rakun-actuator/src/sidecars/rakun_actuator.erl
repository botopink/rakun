%%% rakun-actuator — the endpoint host, BEAM half (front 11).
%%%
%%% WHAT LIVES HERE AND WHY. The parts of the host that need a process, a clock,
%%% a table or the operating system: running every health indicator in its own
%%% process under a deadline, the per-endpoint response cache, the boot-step
%%% record, the mount table, the exposure hook front 76 installs, the info merge
%%% (a JSON parse — there is no std JSON walker), and the facts the built-in
%%% contributors report (OTP release, OS, PID, uptime, disk space).
%%%
%%% WHAT DOES *NOT* LIVE HERE. The status order, the status-to-code mapping, the
%%% normalization of an unknown status, the routing by id, the path mapping, the
%%% exposure default and every refusal text are botopink (`src/*.bp`). This
%%% module never decides which status wins.
%%%
%%% THE REGISTRIES ARE NOT HERE. They belong to `rakun_actuator_api` and are read
%%% through its exported functions, so a restart of this module's owner loses a
%%% cache and a mount record, never a registration.
%%%
%%% MODULE ATOM. `rakun_actuator`, never a module basename the build emits.
-module(rakun_actuator).

-export([run_health/2, json_object_ok/1]).
-export([invoke_endpoint/2]).
-export([cache_get/1, cache_put/3, cache_reset/0]).
-export([meta_put/2, meta_get/1, meta_reset/0]).
-export([exposure_install/1, exposure_installed/0, exposure_ask/1, exposure_clear/0]).
-export([info_merge/1, env_info/0]).
-export([otp_facts/0, os_facts/0, process_facts/0, build_facts/0, disk_facts/2]).
-export([step_record/3, steps/0, steps_reset/0, now_millis/0, run_instrumentation/0,
         boot_mark/1, time_step/2, steps_json/0, steps_total/0]).
-export([file_routes/0]).
-export([ensure/0, owner/1, restart/0]).

-define(CACHE, rakun_actuator_cache).   %% set: {Id, ExpiresAtMonotonicMs, Response}
-define(META, rakun_actuator_meta).     %% set: {Key, Value}
-define(STEPS, rakun_actuator_steps).   %% ordered_set: {Seq, Name, StartedAtMs, DurationMs}
-define(OWNER, rakun_actuator_owner).

%% ═══ lifecycle ═══════════════════════════════════════════════════════════════

ensure() ->
    case ets:whereis(?CACHE) of
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
    after 5000 ->
        erlang:demonitor(Ref, [flush]), ok
    end.

owner(Caller) ->
    case catch erlang:register(?OWNER, self()) of
        true ->
            Common = [named_table, public, {read_concurrency, true}],
            _ = ets:new(?CACHE, [set | Common]),
            _ = ets:new(?META, [set | Common]),
            _ = ets:new(?STEPS, [ordered_set | Common]),
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

%% Kills the host's owner (its tables go with it) and starts a fresh one — what
%% a test calls to prove the registries are not the host's.
restart() ->
    case whereis(?OWNER) of
        undefined -> ok;
        Pid ->
            Ref = erlang:monitor(process, Pid),
            exit(Pid, kill),
            receive {'DOWN', Ref, process, Pid, _} -> ok after 5000 -> ok end
    end,
    ensure(),
    0.

%% ═══ health: one process per indicator, each under its own deadline ══════════
%% `IdsWire` is `id=timeoutMs` lines. Every indicator is spawned at once, so ten
%% indicators at one second each take one second. An indicator past its
%% deadline is KILLED (abandoned, not awaited) and answers `timeout`; one that
%% raises answers `raised` with the reason's text. The answer is one
%% `id\tkind\tpayload` line per indicator, sorted by id, where `kind` is `ok`
%% (payload `status\tdetails`), `raised`, `timeout` or `missing`.

run_health(IdsWire, _Unused) ->
    Parent = self(),
    Now = erlang:monotonic_time(millisecond),
    Jobs = [begin
                {Id, Ms} = parse_job(Line),
                Ref = make_ref(),
                Fun = rakun_actuator_api:health_fun(Id),
                Pid = spawn(fun() -> Parent ! {Ref, attempt(Fun)} end),
                {Id, Ref, Pid, Now + Ms, Ms}
            end || Line <- lines(IdsWire)],
    Answers = [collect(Job) || Job <- Jobs],
    join([<<Id/binary, "\t", A/binary>> || {Id, A} <- lists:keysort(1, Answers)], <<"\n">>).

parse_job(Line) ->
    case binary:split(Line, <<"=">>) of
        [Id, Ms] -> {Id, max(1, binary_to_integer(Ms))};
        [Id] -> {Id, 2000}
    end.

attempt(undefined) ->
    <<"missing\t">>;
attempt(Fun) ->
    try Fun() of
        Line when is_binary(Line) -> <<"ok\t", Line/binary>>;
        Other -> <<"raised\t", (reason_text(Other))/binary>>
    catch
        _Class:Reason -> <<"raised\t", (reason_text(Reason))/binary>>
    end.

collect({Id, Ref, Pid, Deadline, Ms}) ->
    Left = max(0, Deadline - erlang:monotonic_time(millisecond)),
    receive
        {Ref, Answer} -> {Id, Answer}
    after Left ->
        exit(Pid, kill),
        receive {Ref, Late} -> {Id, Late} after 0 -> {Id, <<"timeout\t", (integer_to_binary(Ms))/binary>>} end
    end.

%% The readable text of a raise: a `@panic` message, an `error(Binary)`, or the
%% `~p` of anything else. Never a stack trace — `details` may not carry one.
reason_text(R) when is_binary(R) -> R;
reason_text(R) when is_list(R) ->
    try unicode:characters_to_binary(R) of
        B when is_binary(B) -> B;
        _ -> fmt(R)
    catch _:_ -> fmt(R)
    end;
reason_text(#{message := M}) -> reason_text(M);
reason_text({_Tag, M}) when is_binary(M) -> M;
reason_text({_Tag, M, _}) when is_binary(M) -> M;
reason_text(R) -> fmt(R).

fmt(R) -> iolist_to_binary(io_lib:format("~p", [R])).

json_object_ok(Text) ->
    try json:decode(Text) of
        M when is_map(M) -> true;
        _ -> false
    catch _:_ -> false
    end.

%% ═══ endpoints ═══════════════════════════════════════════════════════════════

invoke_endpoint(Id, Req) ->
    case rakun_actuator_api:endpoint_fun(Id) of
        undefined -> undefined;
        Fun -> Fun(Req)
    end.

%% ═══ the response cache ══════════════════════════════════════════════════════
%% Per endpoint id. A TTL of 0 never stores.

cache_get(Id) ->
    ensure(),
    Now = erlang:monotonic_time(millisecond),
    case ets:lookup(?CACHE, Id) of
        [{_, Expires, Response}] when Expires > Now -> Response;
        _ -> undefined
    end.

cache_put(Id, TtlMs, Response) ->
    ensure(),
    case TtlMs > 0 of
        true ->
            true = ets:insert(?CACHE, {Id, erlang:monotonic_time(millisecond) + TtlMs, Response});
        false -> ok
    end,
    0.

cache_reset() ->
    ensure(),
    true = ets:delete_all_objects(?CACHE),
    0.

%% ═══ the key/value table (mounts) ════════════════════════════════════════════

meta_put(Key, Value) ->
    ensure(),
    true = ets:insert(?META, {Key, Value}),
    0.

meta_get(Key) ->
    ensure(),
    case ets:lookup(?META, Key) of
        [{_, V}] -> V;
        [] -> <<>>
    end.

meta_reset() ->
    ensure(),
    true = ets:delete_all_objects(?META),
    0.

%% ═══ the exposure hook (front 76 installs it) ════════════════════════════════
%% A `persistent_term`, not the cache table: it is set once at boot and read on
%% every request. With nothing installed the botopink default applies.

exposure_install(Fun) ->
    persistent_term:put(rakun_actuator_exposure, Fun),
    0.

exposure_installed() ->
    persistent_term:get(rakun_actuator_exposure, undefined) =/= undefined.

exposure_ask(Id) ->
    case persistent_term:get(rakun_actuator_exposure, undefined) of
        undefined -> false;
        Fun -> Fun(Id) =:= true
    end.

exposure_clear() ->
    _ = persistent_term:erase(rakun_actuator_exposure),
    0.

%% ═══ info: merge by top-level key ════════════════════════════════════════════
%% `IdsWire` is the contributor ids, one per line. Answers `ok\t<merged json>` or
%% `conflict\t<key>\t<first id>\t<second id>`. A contributor that raises or
%% answers something that is not a JSON object contributes nothing.

info_merge(IdsWire) ->
    Contribs = [{Id, contribution(Id)} || Id <- lists:sort(lines(IdsWire))],
    merge(Contribs, #{}, #{}).

contribution(Id) ->
    case rakun_actuator_api:info_fun(Id) of
        undefined -> #{};
        Fun ->
            try json:decode(Fun()) of
                M when is_map(M) -> M;
                _ -> #{}
            catch _:_ -> #{}
            end
    end.

merge([], Acc, _Owners) ->
    <<"ok\t", (iolist_to_binary(json:encode(Acc)))/binary>>;
merge([{Id, M} | Rest], Acc, Owners) ->
    Keys = lists:sort(maps:keys(M)),
    case [K || K <- Keys, maps:is_key(K, Acc)] of
        [K | _] ->
            iolist_to_binary([<<"conflict\t">>, K, <<"\t">>, maps:get(K, Owners), <<"\t">>, Id]);
        [] ->
            merge(Rest, maps:merge(Acc, M), maps:merge(Owners, maps:from_list([{K, Id} || K <- Keys])))
    end.

%% Every property under `info.` as a nested JSON object: `info.app.name=x` →
%% `{"app":{"name":"x"}}`. Read straight from front 04's property table
%% (`rakun_props`, `named_table, public`) because the core has no cell that lists
%% keys by prefix; a key that is both a leaf and a branch keeps the branch, and
%% an empty value is an unset key (front 04's `prop/1` reads absent as `""`).
env_info() ->
    _ = rakun_runtime:ensure_started(),
    Rows = case ets:whereis(rakun_props) of
               undefined -> [];
               _ -> [{K, V} || {K, V} <- ets:tab2list(rakun_props), is_binary(K), V =/= <<>>,
                               binary:longest_common_prefix([K, <<"rakun.info.">>]) =:= 11]
           end,
    Tree = lists:foldl(fun({K, V}, Acc) ->
                               <<"rakun.info.", Rest/binary>> = K,
                               Path = [P || P <- binary:split(Rest, <<".">>, [global]), P =/= <<>>],
                               put_path(Path, V, Acc)
                       end, #{}, lists:sort(Rows)),
    iolist_to_binary(json:encode(Tree)).

put_path([], _V, Acc) -> Acc;
put_path([Leaf], V, Acc) ->
    case maps:get(Leaf, Acc, undefined) of
        M when is_map(M) -> Acc;
        _ -> Acc#{Leaf => V}
    end;
put_path([H | T], V, Acc) ->
    Sub = case maps:get(H, Acc, #{}) of M when is_map(M) -> M; _ -> #{} end,
    Acc#{H => put_path(T, V, Sub)}.

%% ═══ facts the built-in contributors report ══════════════════════════════════

otp_facts() ->
    iolist_to_binary(json:encode(#{<<"otp">> => #{
        <<"release">> => list_to_binary(erlang:system_info(otp_release)),
        <<"erts">> => list_to_binary(erlang:system_info(version)),
        <<"schedulers">> => erlang:system_info(schedulers_online)}})).

os_facts() ->
    {Family, Name} = os:type(),
    Version = case os:version() of
                  {Ma, Mi, Pa} -> iolist_to_binary(io_lib:format("~b.~b.~b", [Ma, Mi, Pa]));
                  V -> list_to_binary(V)
              end,
    iolist_to_binary(json:encode(#{<<"os">> => #{
        <<"family">> => atom_to_binary(Family),
        <<"name">> => atom_to_binary(Name),
        <<"version">> => Version,
        <<"arch">> => list_to_binary(erlang:system_info(system_architecture))}})).

process_facts() ->
    {Uptime, _} = erlang:statistics(wall_clock),
    iolist_to_binary(json:encode(#{<<"process">> => #{
        <<"pid">> => list_to_binary(os:getpid()),
        <<"uptimeMillis">> => Uptime,
        <<"processes">> => erlang:system_info(process_count)}})).

%% `name` and `version` from the working directory's `botopink.json`, `""` each
%% when there is no manifest to read.
build_facts() ->
    {Name, Vsn} = case file:read_file("botopink.json") of
                      {ok, Raw} ->
                          try json:decode(Raw) of
                              #{} = M -> {maps:get(<<"name">>, M, <<>>), maps:get(<<"version">>, M, <<>>)};
                              _ -> {<<>>, <<>>}
                          catch _:_ -> {<<>>, <<>>}
                          end;
                      _ -> {<<>>, <<>>}
                  end,
    <<Name/binary, "\t", Vsn/binary>>.

%% `free\ttotal\tenough` in bytes (`enough` is `1` when free >= the threshold) for the filesystem holding `Path`, from POSIX `df -Pk`
%% (os_mon's `disksup` is an application a minimal node does not start); `""`
%% when the path is unreadable.
disk_facts(Path, Threshold) ->
    Out = os:cmd("df -Pk " ++ shell_quote(binary_to_list(Path)) ++ " 2>/dev/null"),
    case string:split(string:trim(Out), "\n", all) of
        [_Header, Row | _] ->
            case string:lexemes(Row, " ") of
                [_Fs, TotalK, _UsedK, FreeK | _] ->
                    Free = list_to_integer(FreeK) * 1024,
                    Total = list_to_integer(TotalK) * 1024,
                    Enough = case Free >= Threshold of true -> <<"1">>; false -> <<"0">> end,
                    <<(integer_to_binary(Free))/binary, "\t", (integer_to_binary(Total))/binary, "\t", Enough/binary>>;
                _ -> <<>>
            end;
        _ -> <<>>
    end.

shell_quote(S) -> "'" ++ lists:flatten(string:replace(S, "'", "'\\''", all)) ++ "'".

%% ═══ boot steps ══════════════════════════════════════════════════════════════

now_millis() ->
    erlang:system_time(millisecond).

step_record(Name, StartedAt, Duration) ->
    ensure(),
    Seq = erlang:unique_integer([monotonic, positive]),
    true = ets:insert(?STEPS, {Seq, Name, StartedAt, Duration}),
    0.

%% `name\tstartedAtMillis\tdurationMillis` per step, in recording order.
steps() ->
    ensure(),
    join([<<N/binary, "\t", (integer_to_binary(S))/binary, "\t", (integer_to_binary(D))/binary>>
          || {_Seq, N, S, D} <- ets:tab2list(?STEPS)], <<"\n">>).

steps_reset() ->
    ensure(),
    true = ets:delete_all_objects(?STEPS),
    _ = ets:delete(?META, <<"boot last">>),
    0.

%% `boot_mark(<<>>)` starts the clock; `boot_mark(Name)` records the step that
%% ran from the previous mark to now under `Name` and moves the mark. Marks
%% placed at consecutive boot events make steps that are CONTIGUOUS, so they sum
%% to the boot's total by construction.
boot_mark(Name) ->
    ensure(),
    Now = now_millis(),
    case {Name, ets:lookup(?META, <<"boot last">>)} of
        {<<>>, _} -> ok;
        {_, [{_, Last}]} -> step_record(Name, Last, Now - Last);
        {_, []} -> step_record(Name, Now, 0)
    end,
    true = ets:insert(?META, {<<"boot last">>, Now}),
    0.

time_step(Name, Fun) ->
    T0 = now_millis(),
    V = Fun(),
    _ = step_record(Name, T0, now_millis() - T0),
    V.

steps_json() ->
    ensure(),
    Rows = [#{<<"step">> => N, <<"startedAtMillis">> => S, <<"durationMillis">> => D}
            || {_Seq, N, S, D} <- ets:tab2list(?STEPS)],
    iolist_to_binary(json:encode(#{<<"steps">> => Rows, <<"totalMillis">> => steps_total()})).

%% From the first step's start to the last step's end.
steps_total() ->
    ensure(),
    case ets:tab2list(?STEPS) of
        [] -> 0;
        Rows ->
            First = lists:min([S || {_, _, S, _} <- Rows]),
            End = lists:max([S + D || {_, _, S, D} <- Rows]),
            End - First
    end.

%% Runs the application's `#[instrumentation]` function (rakun-actuator-api's
%% registry) at most once per node; answers its owner, `""` when there is none
%% or it already ran.
run_instrumentation() ->
    ensure(),
    case {rakun_actuator_api:instrumentation_fun(), meta_get(<<"instrumentation ran">>)} of
        {undefined, _} -> <<>>;
        {_, <<"1">>} -> <<>>;
        {Fun, _} ->
            _ = meta_put(<<"instrumentation ran">>, <<"1">>),
            _ = Fun(),
            rakun_actuator_api:instrumentation_owner()
    end.

%% ═══ the file-router table (front 22), when it is in the build ═══════════════

file_routes() ->
    _ = code:ensure_loaded(rakun_file_router),
    case erlang:function_exported(rakun_file_router, table, 0) of
        true -> rakun_file_router:table();
        false -> <<>>
    end.

%% ═══ helpers ═════════════════════════════════════════════════════════════════

lines(<<>>) -> [];
lines(Wire) -> [L || L <- binary:split(Wire, <<"\n">>, [global]), L =/= <<>>].

join([], _Sep) -> <<>>;
join(List, Sep) -> iolist_to_binary(lists:join(Sep, List)).
