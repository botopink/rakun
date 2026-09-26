%%% rakun-data — the migration host cells (front 77): the cluster lock, the
%%% statement splitter, the version order, the catch that turns a raise into
%%% an error text, and the table count baselining needs.
%%%
%%% THE LOCK is OTP's `global` lock on `{rakun_migration, Datasource}`, held by
%%% the calling process: every connected node sees it, and it is released
%%% when the holder exits — a node that dies mid-migration frees it. A caller
%%% that cannot take it within the timeout gets `timeout`.

-module(rakun_migration).
-export([with_lock/3, split/1, compare/2, try_run/1, table_count/1, now_iso/0,
         now_ms/0, unlocked_warning/1, warnings/0, lock_events/0, hold_lock/2, release_held/0]).

%% Runs `Fun` holding the lock; answers `Fun()`'s value, or raises
%% `rakun migration: could not take the migration lock within <ms> ms`.
with_lock(Ds, TimeoutMs, Fun) ->
    Id = {{rakun_migration, Ds}, self()},
    Deadline = erlang:monotonic_time(millisecond) + TimeoutMs,
    case acquire(Id, Deadline) of
        ok ->
            note(<<"lock ", Ds/binary>>),
            try Fun()
            after
                global:del_lock(Id, [node() | nodes()]),
                note(<<"unlock ", Ds/binary>>)
            end;
        timeout ->
            erlang:error({panic, iolist_to_binary(
                ["rakun migration: could not take the migration lock for `", Ds, "` within ",
                 integer_to_binary(TimeoutMs), " ms (rakun.migration.lock-timeout) - another node is migrating"])})
    end.

acquire(Id, Deadline) ->
    case global:set_lock(Id, [node() | nodes()], 0) of
        true -> ok;
        false ->
            case erlang:monotonic_time(millisecond) >= Deadline of
                true -> timeout;
                false -> timer:sleep(10), acquire(Id, Deadline)
            end
    end.

note(Line) ->
    persistent_term:put(rakun_migration_lock_log, lock_events() ++ [Line]).

lock_events() -> persistent_term:get(rakun_migration_lock_log, []).

%% Test seam: a process that takes the lock for `Ds` and holds it until
%% `release_held/0` or its death. Answers its pid as text.
hold_lock(Ds, _Unused) ->
    Me = self(),
    Pid = spawn(fun() ->
                        Id = {{rakun_migration, Ds}, self()},
                        true = global:set_lock(Id, [node() | nodes()], 0),
                        Me ! {rakun_migration_held, self()},
                        receive release -> global:del_lock(Id, [node() | nodes()]) end
                end),
    receive {rakun_migration_held, Pid} -> ok after 2000 -> ok end,
    persistent_term:put(rakun_migration_holder, Pid),
    list_to_binary(pid_to_list(Pid)).

release_held() ->
    case persistent_term:get(rakun_migration_holder, undefined) of
        undefined -> 0;
        Pid -> Pid ! release, exit(Pid, kill), persistent_term:erase(rakun_migration_holder), 0
    end.

%% The statements of a script: `;`-separated outside single quotes, with
%% `--` line comments dropped and blank statements removed.
split(Text) ->
    Lines = [L || L <- binary:split(Text, [<<"\r\n">>, <<"\n">>], [global]),
                  not is_comment(L)],
    Joined = iolist_to_binary(lists:join(<<"\n">>, Lines)),
    [S || S <- [string:trim(P) || P <- split_semis(Joined, <<>>, [], false)], S =/= <<>>].

is_comment(L) ->
    case string:trim(L, leading) of
        <<"--", _/binary>> -> true;
        _ -> false
    end.

split_semis(<<>>, Cur, Acc, _Q) -> lists:reverse([Cur | Acc]);
split_semis(<<$', R/binary>>, Cur, Acc, Q) -> split_semis(R, <<Cur/binary, $'>>, Acc, not Q);
split_semis(<<$;, R/binary>>, Cur, Acc, false) -> split_semis(R, <<>>, [Cur | Acc], false);
split_semis(<<C, R/binary>>, Cur, Acc, Q) -> split_semis(R, <<Cur/binary, C>>, Acc, Q).

%% `-1`, `0` or `1`: versions compared component-wise as integers
%% (`1.1` < `1.2` < `2` < `10`), a missing component counting as 0.
compare(A, B) ->
    cmp(parts(A), parts(B)).

parts(V) -> [binary_to_integer(P) || P <- binary:split(V, [<<".">>, <<"_">>], [global]), P =/= <<>>].

cmp([], []) -> 0;
cmp([], B) -> cmp([0], B);
cmp(A, []) -> cmp(A, [0]);
cmp([X | A], [X | B]) -> cmp(A, B);
cmp([X | _], [Y | _]) when X < Y -> -1;
cmp(_, _) -> 1.

%% `<<>>` when `Fun()` returned, the reason text when it raised.
try_run(Fun) ->
    try Fun(), <<>>
    catch _:{panic, R} when is_binary(R) -> R;
          _:R -> iolist_to_binary(io_lib:format("~p", [R]))
    end.

%% How many tables the datasource holds besides the history table (ETS arm;
%% another arm asks information_schema through rakun_sql).
table_count(Ds) ->
    case rakun_sql:ds_arm(Ds) of
        <<"ets">> ->
            length([T || {{D, T}, _, _} <- ets:tab2list(rakun_sql_data), D =:= Ds,
                         T =/= <<"rakun_schema_history">>]);
        _ ->
            case rakun_sql:exec(Ds, <<"SELECT count(*) AS n FROM information_schema.tables WHERE table_schema = current_schema() AND table_name <> 'rakun_schema_history'">>, []) of
                #{ok := true, rows := [[N] | _]} -> binary_to_integer(N);
                _ -> 0
            end
    end.

now_iso() ->
    list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second), [{offset, "Z"}])).

now_ms() -> erlang:monotonic_time(millisecond).

%% Once per driver: the arm has no advisory lock and the node is not
%% distributed, so the lock is node-local.
unlocked_warning(Ds) ->
    Key = {rakun_migration_warned, rakun_sql:ds_arm(Ds)},
    case persistent_term:get(Key, false) of
        true -> 0;
        false ->
            persistent_term:put(Key, true),
            Line = iolist_to_binary(["rakun migration: the ", rakun_sql:ds_arm(Ds),
                                     " driver has no advisory lock and this node is not in a cluster - ",
                                     "the migration lock covers this node only"]),
            persistent_term:put(rakun_migration_warnings, warnings() ++ [Line]),
            logger:warning("~ts", [Line]),
            1
    end.

warnings() -> persistent_term:get(rakun_migration_warnings, []).
