%%% rakun-logging — the OTP `logger` seam. Front 17.
%%%
%%% WHAT LIVES HERE. The parts no string table can hold and the parts only the
%%% runtime can answer: the call into `logger:log/3`, the formatter module OTP
%%% hands every rakun record to, the capturing handler the tests read records
%%% back from, the `logger_std_h` console and file handlers, the run-time level
%%% overrides, the correlation slot (the process dictionary), the facts a record
%%% carries (clock, pid, node), the `sys.config` consult and the log-file reads.
%%%
%%% WHAT DOES *NOT* LIVE HERE. The level resolver, the groups, the four schemas,
%%% the escaping, the digest and the endpoints are botopink (`src/*.bp`). A
%%% record reaches this module already rendered: `emit/6` carries the console
%%% line and the file line in the metadata and `format/2` only picks the one its
%%% handler was configured for. So the schema a collector sees is the schema the
%%% tests assert, byte for byte, with no second renderer to drift.
%%%
%%% THE TRACE/DEBUG COLLAPSE. OTP has no `trace`: both rakun levels land on OTP
%%% `debug`. The botopink side has already discarded a record below the logger's
%%% level before `emit/6` is called; the rakun level rides in the metadata
%%% (`rk_level`) so a handler can still tell the two apart.
%%%
%%% TABLE OWNERSHIP. The capture table dies with the process that created it,
%%% so it is created by a dedicated owner process (`rakun_logging_owner`), the
%%% shape of `rakun_actuator_api`.
-module(rakun_logging).

-export([ensure_otp/0, emit/6, format/2, log/2]).
-export([fix_facts/3, unfix_facts/0, now_ms/0, pid_str/0, node_str/0, thread_name/0,
         iso/1, gelf_ts/1, os_pid/0, uptime_ms/0]).
-export([prop_keys/1]).
-export([override_get/1, override_set/2, override_clear/1, override_names/0, override_reset/0]).
-export([register_name/1, registered_names/0]).
-export([corr_get/0, corr_set/1, fresh_id/0]).
-export([capture_start/1, capture_lines/1, capture_count/0, capture_stop/0]).
-export([install_console/1, install_file/4, remove_handlers/0, handler_ids/0,
         wants_file/0, file_sync/0]).
-export([consult/1, file_size/1, read_range/3, list_dir/1, delete_file/1, write_file/2,
         make_dir/1]).
-export([ensure/0, owner/1]).

-define(OWNER, rakun_logging_owner).
-define(CAPTURE, rakun_logging_capture).      %% ordered_set: {Seq, Target, Line}
-define(FACTS, {rakun_logging, facts}).       %% persistent_term: {Ms, Pid, Node} | undefined
-define(OVERRIDES, {rakun_logging, overrides}). %% persistent_term: #{Name => Level}
-define(NAMES, {rakun_logging, names}).       %% persistent_term: #{Name => true}
-define(READY, {rakun_logging, otp_ready}).   %% persistent_term: true once OTP is prepared
-define(WANTS_FILE, {rakun_logging, wants_file}).
-define(CORR, rakun_logging_correlation).     %% process dictionary
-define(CONSOLE_H, rakun_console).
-define(FILE_H, rakun_file).
-define(CAPTURE_H(T), list_to_atom("rakun_capture_" ++ binary_to_list(T))).

%% ═══ lifecycle ═══════════════════════════════════════════════════════════════

ensure() ->
    case ets:whereis(?CAPTURE) of
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
            _ = ets:new(?CAPTURE, [ordered_set, named_table, public]),
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

%% OTP's primary level defaults to `notice`, which would drop every rakun
%% `info` and `debug` record before any handler saw it. rakun decides levels
%% itself, so the primary level opens to `all` — and the `default` handler,
%% which would otherwise start printing every OTP application's debug records,
%% is closed back to the old primary level and told to stop rakun's domain
%% (rakun's own handlers print those, in rakun's schemas).
ensure_otp() ->
    case persistent_term:get(?READY, false) of
        true -> 0;
        false ->
            #{level := Old} = logger:get_primary_config(),
            ok = logger:set_primary_config(level, all),
            case logger:get_handler_config(default) of
                {ok, _} ->
                    _ = logger:set_handler_config(default, level, Old),
                    _ = logger:add_handler_filter(default, rakun_stop,
                                                  {fun logger_filters:domain/2, {stop, sub, [rakun]}});
                _ -> ok
            end,
            persistent_term:put(?READY, true),
            0
    end.

%% ═══ the record ══════════════════════════════════════════════════════════════

emit(OtpLevel, RakunLevel, Name, ConsoleLine, FileLine, Trace) ->
    _ = ensure_otp(),
    Level = binary_to_existing_atom(OtpLevel, utf8),
    logger:log(Level, "~ts", [ConsoleLine],
               #{domain => [rakun], rk_level => RakunLevel, rk_logger => Name,
                 rk_console => ConsoleLine, rk_file => FileLine, rk_trace => Trace}),
    0.

%% The formatter every rakun handler is configured with. A rakun record is
%% already rendered; anything else goes through OTP's own formatter.
format(#{meta := #{rk_console := C} = M} = _Event, Config) ->
    Line = case maps:get(target, Config, <<"console">>) of
               <<"file">> -> maps:get(rk_file, M, C);
               _ -> C
           end,
    [Line, $\n];
format(Event, _Config) ->
    logger_formatter:format(Event, #{}).

%% The capturing handler: a `logger` handler module whose `log/2` stores the
%% line its target would have written. Tests read records back from here, not
%% from stdout.
log(#{meta := M} = Event, #{config := #{target := Target}}) ->
    case M of
        #{rk_console := _} ->
            Line = iolist_to_binary(format(Event, #{target => Target})),
            Trimmed = binary:part(Line, 0, byte_size(Line) - 1),
            ensure(),
            true = ets:insert(?CAPTURE, {erlang:unique_integer([monotonic]), Target, Trimmed}),
            ok;
        _ -> ok
    end;
log(_, _) ->
    ok.

%% ═══ facts ═══════════════════════════════════════════════════════════════════

%% The test seam: a fixed clock (whole seconds), pid text and node text.
fix_facts(Seconds, Pid, Node) ->
    persistent_term:put(?FACTS, {Seconds * 1000, Pid, Node}),
    0.

unfix_facts() ->
    _ = persistent_term:erase(?FACTS),
    0.

now_ms() ->
    case persistent_term:get(?FACTS, undefined) of
        {Ms, _, _} -> Ms;
        undefined -> erlang:system_time(millisecond)
    end.

pid_str() ->
    case persistent_term:get(?FACTS, undefined) of
        {_, Pid, _} -> Pid;
        undefined -> list_to_binary(pid_to_list(self()))
    end.

node_str() ->
    case persistent_term:get(?FACTS, undefined) of
        {_, _, Node} -> Node;
        undefined -> atom_to_binary(node(), utf8)
    end.

thread_name() ->
    case persistent_term:get(?FACTS, undefined) of
        {_, _, _} -> <<"main">>;
        undefined ->
            case erlang:process_info(self(), registered_name) of
                {registered_name, N} when is_atom(N) -> atom_to_binary(N, utf8);
                _ -> <<"main">>
            end
    end.

%% ISO-8601 in UTC; the fraction is written only when there is one, so a
%% record on a whole second reads `2026-01-01T00:00:00Z`.
iso(Ms) ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:system_time_to_universal_time(Ms div 1000, second),
    Frac = Ms rem 1000,
    Base = io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0B", [Y, Mo, D, H, Mi, S]),
    Tail = case Frac of 0 -> "Z"; _ -> io_lib:format(".~3..0BZ", [Frac]) end,
    iolist_to_binary([Base, Tail]).

gelf_ts(Ms) ->
    case Ms rem 1000 of
        0 -> integer_to_binary(Ms div 1000);
        F -> iolist_to_binary(io_lib:format("~B.~3..0B", [Ms div 1000, F]))
    end.

os_pid() ->
    list_to_binary(os:getpid()).

uptime_ms() ->
    {Total, _} = erlang:statistics(wall_clock),
    Total.

%% ═══ configuration keys ══════════════════════════════════════════════════════

%% Every property key under `Prefix`, sorted, newline-joined. The group table
%% is keyed by name (`rakun.logging.group.<name>`), so the resolver has to list
%% keys, which front 05's `prop/1` cannot.
prop_keys(Prefix) ->
    case ets:whereis(rakun_props) of
        undefined -> <<>>;
        _ ->
            N = byte_size(Prefix),
            Keys = [K || {K, V} <- ets:tab2list(rakun_props), is_binary(K), V =/= <<>>,
                         byte_size(K) > N, binary:part(K, 0, N) =:= Prefix],
            join(lists:sort(Keys), <<"\n">>)
    end.

%% ═══ run-time overrides (the `loggers` endpoint) ═════════════════════════════

override_get(Name) ->
    maps:get(Name, persistent_term:get(?OVERRIDES, #{}), <<>>).

override_set(Name, Level) ->
    persistent_term:put(?OVERRIDES, maps:put(Name, Level, persistent_term:get(?OVERRIDES, #{}))),
    0.

override_clear(Name) ->
    persistent_term:put(?OVERRIDES, maps:remove(Name, persistent_term:get(?OVERRIDES, #{}))),
    0.

override_names() ->
    join(lists:sort(maps:keys(persistent_term:get(?OVERRIDES, #{}))), <<"\n">>).

override_reset() ->
    _ = persistent_term:erase(?OVERRIDES),
    0.

register_name(Name) ->
    Names = persistent_term:get(?NAMES, #{}),
    case maps:is_key(Name, Names) of
        true -> 0;
        false -> persistent_term:put(?NAMES, maps:put(Name, true, Names)), 0
    end.

registered_names() ->
    join(lists:sort(maps:keys(persistent_term:get(?NAMES, #{}))), <<"\n">>).

%% ═══ correlation ═════════════════════════════════════════════════════════════

corr_get() ->
    case get(?CORR) of
        undefined -> <<>>;
        V -> V
    end.

corr_set(<<>>) ->
    _ = erase(?CORR),
    0;
corr_set(Id) ->
    _ = put(?CORR, Id),
    0.

%% 16 hex characters from `rand`: a correlation handle, not a secret.
fresh_id() ->
    Bytes = rand:bytes(8),
    string:lowercase(binary:encode_hex(Bytes)).

%% ═══ capture ═════════════════════════════════════════════════════════════════

capture_start(Target) ->
    ensure(),
    _ = ensure_otp(),
    Id = ?CAPTURE_H(Target),
    _ = logger:remove_handler(Id),
    ok = logger:add_handler(Id, ?MODULE, #{level => all, config => #{target => Target},
                                            filters => [{rakun_only, {fun logger_filters:domain/2, {stop, not_equal, [rakun]}}}]}),
    case Target of
        <<"file">> -> persistent_term:put(?WANTS_FILE, true);
        _ -> ok
    end,
    0.

capture_lines(Target) ->
    ensure(),
    join([L || {_, T, L} <- ets:tab2list(?CAPTURE), T =:= Target], <<"\n">>).

capture_count() ->
    ensure(),
    ets:info(?CAPTURE, size).

capture_stop() ->
    ensure(),
    [logger:remove_handler(Id) || Id <- logger:get_handler_ids(),
                                  lists:prefix("rakun_capture_", atom_to_list(Id))],
    true = ets:delete_all_objects(?CAPTURE),
    refresh_wants_file(),
    0.

%% ═══ console and file handlers ═══════════════════════════════════════════════

rakun_filters() ->
    [{rakun_only, {fun logger_filters:domain/2, {stop, not_equal, [rakun]}}}].

%% `Threshold` is the OTP level name of `rakun.logging.threshold.console`
%% (`all` when unset, `none` for `off`).
install_console(Threshold) ->
    _ = ensure_otp(),
    _ = logger:remove_handler(?CONSOLE_H),
    ok = logger:add_handler(?CONSOLE_H, logger_std_h,
                            #{level => binary_to_existing_atom(Threshold, utf8), config => #{type => standard_io},
                              filters => rakun_filters(),
                              formatter => {?MODULE, #{target => <<"console">>}}}),
    0.

%% `logger_std_h` owns rotation: `max_no_bytes` per file and `max_no_files`
%% rotated archives (`<file>.0` … `<file>.N-1`); the handler deletes the
%% oldest itself. The total cap is folded into the archive count by the caller.
install_file(Path, MaxBytes, MaxFiles, Threshold) ->
    _ = ensure_otp(),
    _ = logger:remove_handler(?FILE_H),
    ok = filelib:ensure_dir(Path),
    ok = logger:add_handler(?FILE_H, logger_std_h,
                            #{level => binary_to_existing_atom(Threshold, utf8),
                              config => #{type => file, file => binary_to_list(Path),
                                          max_no_bytes => MaxBytes, max_no_files => MaxFiles,
                                          filesync_repeat_interval => no_repeat},
                              filters => rakun_filters(),
                              formatter => {?MODULE, #{target => <<"file">>}}}),
    persistent_term:put(?WANTS_FILE, true),
    0.

remove_handlers() ->
    _ = logger:remove_handler(?CONSOLE_H),
    _ = logger:remove_handler(?FILE_H),
    refresh_wants_file(),
    0.

handler_ids() ->
    Ids = [atom_to_binary(Id, utf8) || Id <- logger:get_handler_ids(),
                                       lists:prefix("rakun_", atom_to_list(Id))],
    join(lists:sort(Ids), <<"\n">>).

refresh_wants_file() ->
    Ids = logger:get_handler_ids(),
    Wants = lists:member(?FILE_H, Ids) orelse lists:member(rakun_capture_file, Ids),
    persistent_term:put(?WANTS_FILE, Wants).

wants_file() ->
    persistent_term:get(?WANTS_FILE, false).

file_sync() ->
    case lists:member(?FILE_H, logger:get_handler_ids()) of
        true -> _ = logger_std_h:filesync(?FILE_H), 0;
        false -> 0
    end.

%% ═══ sys.config ══════════════════════════════════════════════════════════════

%% `[{rakun_logging, Entries}]` where an entry is `{Key, Value}` or
%% `{profile, Name, Entries}`. Answers one `profile\tkey\tvalue` line per
%% setting (profile empty for an unconditional one), or `error\t<reason>`.
consult(Path) ->
    case file:consult(binary_to_list(Path)) of
        {ok, [Terms]} when is_list(Terms) -> consult_terms(Terms);
        {ok, Terms} when is_list(Terms) -> consult_terms(Terms);
        {error, Reason} ->
            iolist_to_binary(["error\t", io_lib:format("~p", [Reason])])
    end.

consult_terms(Terms) ->
    case lists:keyfind(rakun_logging, 1, Terms) of
        {rakun_logging, Entries} when is_list(Entries) ->
            try join(lists:flatmap(fun(E) -> entry(<<>>, E) end, Entries), <<"\n">>)
            catch throw:{bad, T} -> iolist_to_binary(["error\t", io_lib:format("~p", [T])])
            end;
        _ -> <<"error\tno {rakun_logging, [...]} section">>
    end.

entry(<<>>, {profile, Name, Entries}) when is_list(Entries) ->
    P = text(Name),
    lists:flatmap(fun(E) -> entry(P, E) end, Entries);
entry(P, {K, V}) ->
    [iolist_to_binary([P, $\t, text(K), $\t, text(V)])];
entry(_, T) ->
    throw({bad, T}).

text(V) when is_binary(V) -> V;
text(V) when is_atom(V) -> atom_to_binary(V, utf8);
text(V) when is_integer(V) -> integer_to_binary(V);
text(V) when is_list(V) -> unicode:characters_to_binary(V);
text(V) -> throw({bad, V}).

%% ═══ files ═══════════════════════════════════════════════════════════════════

file_size(Path) ->
    case file:read_file_info(binary_to_list(Path)) of
        {ok, Info} -> element(2, Info);
        _ -> -1
    end.

%% Bytes `[Start, End]` inclusive, clamped to the file.
read_range(Path, Start, End) ->
    case file:open(binary_to_list(Path), [read, binary, raw]) of
        {ok, Fd} ->
            R = file:pread(Fd, Start, End - Start + 1),
            _ = file:close(Fd),
            case R of {ok, Data} -> Data; _ -> <<>> end;
        _ -> <<>>
    end.

list_dir(Dir) ->
    case file:list_dir(binary_to_list(Dir)) of
        {ok, Names} -> join(lists:sort([list_to_binary(N) || N <- Names]), <<"\n">>);
        _ -> <<>>
    end.

delete_file(Path) ->
    _ = file:delete(binary_to_list(Path)),
    0.

write_file(Path, Data) ->
    ok = filelib:ensure_dir(binary_to_list(Path)),
    ok = file:write_file(binary_to_list(Path), Data),
    0.

make_dir(Dir) ->
    ok = filelib:ensure_path(binary_to_list(Dir)),
    0.

%% ═══ helpers ═════════════════════════════════════════════════════════════════

join([], _) -> <<>>;
join(Parts, Sep) -> iolist_to_binary(lists:join(Sep, Parts)).
