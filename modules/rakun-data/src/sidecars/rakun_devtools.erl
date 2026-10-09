%%% rakun-devtools — the watcher, the reload and the guards (front 80).
%%%
%%% THE WATCHER is a process under a keeper: it polls the source roots every
%%% `PollMs`, diffs file mtimes (excluded paths skipped) and calls the
%%% reload function ONCE per cycle with every file that changed; with a
%%% trigger file, changes accumulate until the trigger's mtime moves. Killing
%%% it makes the keeper start a fresh one, which snapshots without reloading.
%%%
%%% THE RELOAD drops what a module registered in front 04's tables — routes
%%% whose handler fun was defined in it, singletons and scan entries of the
%%% types it declares (`<module>@@<Type>`) — then loads the new code and
%%% soft-purges the old: a process still running old code keeps it, and the
%%% answer says so rather than killing it.

-module(rakun_devtools).
-export([watch_start/5, watch_stop/0, watch_pid/0, reloads/0,
         drop_module/1, owner/1, load_dir/1, compile_project/2,
         remote_load/4, trace_calls/3, trace_count/0, constant_eq/2]).

-define(KEEPER, rakun_devtools_keeper).
-define(WATCHER, rakun_devtools_watcher).

%% ═══ the watcher ═════════════════════════════════════════════════════════════

watch_start(Roots, Excludes, Trigger, PollMs, OnChange) ->
    watch_stop(),
    Pid = spawn(fun() ->
                        register(?KEEPER, self()),
                        process_flag(trap_exit, true),
                        keep(Roots, Excludes, Trigger, PollMs, OnChange)
                end),
    wait_watcher(50),
    list_to_binary(pid_to_list(Pid)).

wait_watcher(0) -> ok;
wait_watcher(N) ->
    case whereis(?WATCHER) of
        undefined -> timer:sleep(10), wait_watcher(N - 1);
        _ -> ok
    end.

keep(Roots, Excludes, Trigger, PollMs, OnChange) ->
    W = spawn_link(fun() ->
                           register(?WATCHER, self()),
                           loop(Roots, Excludes, Trigger, PollMs, OnChange, snapshot(Roots, Excludes), mtime(Trigger), [])
                   end),
    receive
        {'EXIT', W, _} -> keep(Roots, Excludes, Trigger, PollMs, OnChange);
        stop -> exit(W, kill), ok
    end.

watch_stop() ->
    case whereis(?KEEPER) of
        undefined -> 0;
        K -> K ! stop, wait_gone(50), 0
    end.

wait_gone(0) -> ok;
wait_gone(N) ->
    case whereis(?KEEPER) =:= undefined andalso whereis(?WATCHER) =:= undefined of
        true -> ok;
        false -> timer:sleep(10), wait_gone(N - 1)
    end.

watch_pid() ->
    case whereis(?WATCHER) of
        undefined -> <<>>;
        P -> list_to_binary(pid_to_list(P))
    end.

reloads() -> persistent_term:get(rakun_devtools_reloads, 0).

loop(Roots, Excludes, Trigger, PollMs, OnChange, Snap, TrigMtime, Pending) ->
    timer:sleep(PollMs),
    Next = snapshot(Roots, Excludes),
    Changed = [F || {F, M} <- maps:to_list(Next), maps:get(F, Snap, undefined) =/= M]
        ++ [F || F <- maps:keys(Snap), not maps:is_key(F, Next)],
    All = lists:usort(Pending ++ Changed),
    NewTrig = mtime(Trigger),
    Fire = case Trigger of
               <<>> -> All =/= [];
               _ -> NewTrig =/= TrigMtime andalso All =/= []
           end,
    case Fire of
        true ->
            persistent_term:put(rakun_devtools_reloads, reloads() + 1),
            _ = (try OnChange(iolist_to_binary(lists:join(<<"\n">>, All))) catch _:_ -> ok end),
            loop(Roots, Excludes, Trigger, PollMs, OnChange, Next, NewTrig, []);
        false ->
            Keep = case Trigger of <<>> -> []; _ -> All end,
            loop(Roots, Excludes, Trigger, PollMs, OnChange, Next, NewTrig, Keep)
    end.

mtime(<<>>) -> none;
mtime(File) ->
    case file:read_file_info(File, [{time, posix}]) of
        {ok, I} -> {element(6, I), element(2, I)};
        _ -> none
    end.

snapshot(Roots, Excludes) ->
    Res = [begin {ok, R} = re:compile(glob_re(E)), R end || E <- Excludes],
    maps:from_list(lists:append([files(Root, Res) || Root <- Roots])).

files(Root, Res) ->
    R = binary_to_list(Root),
    filelib:fold_files(R, ".*", true,
                       fun(F, Acc) ->
                               Rel = list_to_binary(F),
                               case lists:any(fun(Re) -> re:run(Rel, Re) =/= nomatch end, Res) of
                                   true -> Acc;
                                   false -> [{Rel, mtime(Rel)} | Acc]
                               end
                       end, []).

%% `**` any path, `*` within a segment, `?` one character; anchored at the end
%% of the path so `*.tmp` matches a file anywhere.
glob_re(G) ->
    Body = glob(G, <<>>),
    <<"(^|/)", Body/binary, "$">>.

glob(<<"**", R/binary>>, Acc) -> glob(R, <<Acc/binary, ".*">>);
glob(<<"*", R/binary>>, Acc) -> glob(R, <<Acc/binary, "[^/]*">>);
glob(<<"?", R/binary>>, Acc) -> glob(R, <<Acc/binary, "[^/]">>);
glob(<<C, R/binary>>, Acc) ->
    E = case lists:member(C, ".^$+()[]{}|\\") of
            true -> <<"\\", C>>;
            false -> <<C>>
        end,
    glob(R, <<Acc/binary, E/binary>>);
glob(<<>>, Acc) -> Acc.

%% ═══ dropping a module's registrations ═══════════════════════════════════════

type_prefix(Mod) -> <<(atom_to_binary(Mod))/binary, "@@">>.

owned_value(V, Mod) when is_tuple(V), tuple_size(V) >= 1, is_atom(element(1, V)) ->
    P = type_prefix(Mod),
    binary:longest_common_prefix([atom_to_binary(element(1, V)), P]) =:= byte_size(P);
owned_value(_, _) -> false.

fun_module(F) when is_function(F) -> element(2, erlang:fun_info(F, module));
fun_module(_) -> undefined.

type_names(Mod) ->
    P = type_prefix(Mod),
    N = byte_size(P),
    [binary:part(B, N, byte_size(B) - N) || {M, _} <- code:all_loaded(),
                                            B <- [atom_to_binary(M)],
                                            byte_size(B) > N,
                                            binary:longest_common_prefix([B, P]) =:= N].

%% Removes every route whose handler was defined in `Mod`, every singleton of
%% a type `Mod` declares, and their scan entries; answers the rows removed.
drop_module(Mod0) ->
    Mod = binary_to_atom(Mod0),
    Routes = [K || {K, _, _, _, H} <- tab(rakun_routes), fun_module(H) =:= Mod],
    Types = type_names(Mod),
    Singles = [K || {K, V} <- tab(rakun_singletons), owned_value(V, Mod) orelse lists:member(K, Types)],
    Scans = [K || {K, Name} <- tab(rakun_scan), lists:member(Name, Types)],
    [ets:delete(rakun_routes, K) || K <- Routes],
    [ets:delete(rakun_singletons, K) || K <- Singles],
    [ets:delete(rakun_scan, K) || K <- Scans],
    length(Routes) + length(Singles) + length(Scans).

tab(T) ->
    case ets:whereis(T) of
        undefined -> [];
        _ -> ets:tab2list(T)
    end.

%% `route <verb> <path>` / `singleton <name>` lines for what `Mod` owns.
owner(Mod0) ->
    Mod = binary_to_atom(Mod0),
    Types = type_names(Mod),
    Lines = [iolist_to_binary(["route ", V, " ", P]) || {_, V, P, _, H} <- tab(rakun_routes), fun_module(H) =:= Mod]
        ++ [iolist_to_binary(["singleton ", K]) || {K, V} <- tab(rakun_singletons), owned_value(V, Mod) orelse lists:member(K, Types)],
    iolist_to_binary(lists:join(<<"\n">>, lists:sort(Lines))).

%% ═══ compile and load ════════════════════════════════════════════════════════

%% Runs the botopink CLI in `ProjectDir` for the erlang target into
%% `<ProjectDir>/.rakun-devtools/out`. Answers `ok\t<erl dir>` or
%% `error\t<the compiler's own output>`.
compile_project(Bin, ProjectDir) ->
    Out = filename:join([binary_to_list(ProjectDir), ".rakun-devtools", "out"]),
    Cmd = "cd '" ++ binary_to_list(ProjectDir) ++ "' && '" ++ binary_to_list(Bin) ++
        "' build --target erlang --out '" ++ Out ++ "' 2>&1; echo \"exit=$?\"",
    Text = unicode:characters_to_binary(os:cmd(Cmd)),
    case binary:match(Text, <<"exit=0">>) of
        nomatch -> <<"error\t", (binary:replace(Text, <<"exit=1\n">>, <<>>))/binary>>;
        _ -> <<"ok\t", (list_to_binary(filename:join(Out, "erl")))/binary>>
    end.

%% Compiles and loads every `.erl` under `Dir` whose module is new or whose
%% code changed: its registrations dropped first, the new code loaded, its
%% module body (`_botopink_init/0`, the emitted registrations) re-run. Answers
%% `<loaded>|<deferred>` — deferred counts modules whose old version a process
%% was still running (the soft purge refused): those are left to finish.
load_dir(Dir) ->
    Files = filelib:wildcard(filename:join([binary_to_list(Dir), "**", "*.erl"])),
    {Loaded, Deferred} =
        lists:foldl(fun(F, {L, D}) ->
                            case compile:file(F, [binary, return_errors]) of
                                {ok, Mod, Bin} ->
                                    case same_code(Mod, Bin) of
                                        true -> {L, D};
                                        false ->
                                            Def = case code:is_loaded(Mod) of
                                                      false -> 0;
                                                      _ -> case code:soft_purge(Mod) of true -> 0; false -> 1 end
                                                  end,
                                            case Def of
                                                1 -> {L, D + 1};
                                                0 ->
                                                    _ = drop_module(atom_to_binary(Mod)),
                                                    {module, Mod} = code:load_binary(Mod, F, Bin),
                                                    _ = case erlang:function_exported(Mod, '_botopink_init', 0) of
                                                            true -> (try Mod:'_botopink_init'() catch _:_ -> ok end);
                                                            false -> ok
                                                        end,
                                                    {L + 1, D}
                                            end
                                    end;
                                _ -> {L, D}
                            end
                    end, {0, 0}, Files),
    iolist_to_binary([integer_to_binary(Loaded), "|", integer_to_binary(Deferred)]).

same_code(Mod, Bin) ->
    case code:is_loaded(Mod) of
        false -> false;
        _ ->
            case beam_lib:md5(Bin) of
                {ok, {_, Md5}} -> Mod:module_info(md5) =:= Md5;
                _ -> false
            end
    end.

%% ═══ remote loading and tracing ══════════════════════════════════════════════

%% The four guards, in order; `ok` loads `Mod` on every connected node.
remote_load(Mod, DevActive, Configured, {Presented, Tls}) ->
    if
        not DevActive -> <<"refused: remote loading needs an active dev profile">>;
        Configured =:= <<>> -> <<"refused: rakun.devtools.remote.secret is not set">>;
        not Tls -> <<"refused: remote loading is served over TLS only">>;
        true ->
            case constant_eq(Configured, Presented) of
                false -> <<"refused: the secret does not match">>;
                true ->
                    _ = c:nl(binary_to_atom(Mod)),
                    <<"ok">>
            end
    end.

%% Compares every byte whatever the first difference, so the time taken says
%% nothing about how much of the secret matched.
constant_eq(A, B) when byte_size(A) =/= byte_size(B) ->
    _ = constant_eq(A, A),
    false;
constant_eq(A, B) ->
    lists:foldl(fun({X, Y}, Acc) -> Acc bor (X bxor Y) end, 0,
                lists:zip(binary_to_list(A), binary_to_list(B))) =:= 0.

%% Traces calls to `Mod:Fun` and stops by itself after `Limit` messages.
trace_calls(Mod0, Fun0, Limit) when is_integer(Limit), Limit > 0 ->
    Mod = binary_to_atom(Mod0),
    Fun = binary_to_atom(Fun0),
    persistent_term:put(rakun_devtools_traced, 0),
    Handler = fun(_Msg, N) when N >= Limit -> N;
                 (_Msg, N) when N + 1 >= Limit ->
                      persistent_term:put(rakun_devtools_traced, N + 1),
                      spawn(fun() -> dbg:stop() end),
                      N + 1;
                 (_Msg, N) ->
                      persistent_term:put(rakun_devtools_traced, N + 1),
                      N + 1
              end,
    _ = dbg:stop(),
    {ok, _} = dbg:tracer(process, {Handler, 0}),
    {ok, _} = dbg:p(all, c),
    {ok, _} = dbg:tpl(Mod, Fun, '_', []),
    0.

trace_count() -> persistent_term:get(rakun_devtools_traced, 0).
