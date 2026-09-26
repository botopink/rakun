%%% rakun — the host runtime on the BEAM: the node twin `src/runtime.mjs` left with
%%% front 04 Step 10 (decision 113).
%%%
%%% botopink is immutable-first and has no top-level mutable state, so rakun's
%%% runtime state — the component scan registry, the dependency-cycle guard,
%%% the singleton cache, the property map and the router table — lives in the
%%% host, reached from `src/runtime.bp` through `#[@External.Erlang(…)]`
%%% declarations. This module is the host half of that seam; rakun is
%%% erlang-only (decision 113). Comments citing `runtime.mjs:N` name the node
%%% implementation this module was ported from, term for term.
%%%
%%% MODULE ATOM. The file is `src/sidecars/rakun_runtime.erl`, never
%%% `src/runtime.erl`: `shipErlSidecars` skips any qualifier atom that matches a
%%% module the build emitted, and rakun emits `rakun/runtime` — basename
%%% `runtime`. A sidecar called `runtime.erl` would be skipped SILENTLY (the
%%% build exits 0 and the program dies with `undefined function runtime:scan/1`).
%%% Every rakun sidecar is `rakun_<name>.erl`.
%%%
%%% ONE MODULE, THREE OTP ROLES. `shipErlSidecars` copies a sidecar only when
%%% its atom appears as an `atom:fun(` qualifier in the EMITTED botopink output.
%%% `rakun_sup`, `rakun_registry` and `rakun_conn_sup` are never named by
%%% botopink code, so separate `.erl` files for them would never be shipped and
%%% the acceptor would die with `undefined function rakun_sup:start_link/0`.
%%% They are therefore registered NAMES, not modules: `?MODULE` is the callback
%%% module for the application, the two supervisors and the table-owning
%%% gen_server, and `init/1` dispatches on its argument (`sup` | `conn_sup` |
%%% `registry`). Only `-behaviour(application)` is declared: adding
%%% `-behaviour(supervisor)` and `-behaviour(gen_server)` beside it makes erlc
%%% emit "conflicting behaviours ... init/1", which `-Werror` turns into a
%%% failure. The callbacks are all here and the shapes are the OTP ones.
%%%
%%% STORAGE. Six `named_table, public` ETS tables owned by the `rakun_registry`
%%% process, which is a permanent child of `rakun_sup`: a table dies with its
%%% owner, so the owner is a process that never exits on its own, and a crash
%%% that does take it down is restarted into empty tables rather than dangling
%%% ones. `read_concurrency` so a request process reads without a message round
%%% trip; nothing here needs the mailbox except the tables' creation.
%%%
%%% PER-REQUEST STATE. The cycle guard and the reply-header accumulator are in
%%% the process dictionary. On node, "per process" is what single-threadedness
%%% gives by accident; on the BEAM a request IS a process, so per-process is
%%% exactly the scope both need.
-module(rakun_runtime).
-behaviour(application).

%% ── the cells of `src/runtime.bp` ────────────────────────────────────────────
-export([scan/1, scanned_names/0, scanned_count/0,
         enter/1, done/1,
         singleton/2, build_count/1,
         set_prop/2, prop/1, prop_int/1,
         register_route/3, route_count/0, route_paths/0,
         dispatch/2, dispatch_http/5,
         serve/2]).

%% ── server surface with no node twin (`runtime.mjs` is frozen) ───────────────
-export([set_reply_header/2, reply_headers_json/0, clear_reply_headers/0,
         boot/1, add_failure/3, diagnose/1]).

%% ── lifecycle, reachable for a test or a later front ─────────────────────────
-export([ensure_started/0, stop_app/0, bound_port/0]).

%% ── application callback ─────────────────────────────────────────────────────
-export([start/2, stop/1]).

%% ── supervisor + gen_server callbacks (see ONE MODULE, THREE OTP ROLES) ──────
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% ── supervised entry points ──────────────────────────────────────────────────
-export([start_registry/0, start_conn_sup/0, start_listener/2,
         start_connection/2, connection/2]).

-define(SCAN,     rakun_scan).        %% ordered_set: {Seq, Name}
-define(SINGLE,   rakun_singletons).  %% set:         {Name, Value}
-define(BUILDS,   rakun_builds).      %% set:         {Name, Count}
-define(PROPS,    rakun_props).       %% set:         {Key, Value}
-define(ROUTES,   rakun_routes).      %% ordered_set: {Seq, Verb, Path, Segs, Handler}
-define(FAILURES, rakun_failures).    %% set:         {Term, Description, Action}
-define(LOCKS,    rakun_build_locks). %% set:         {Name, Pid} — first construction in flight

-define(DEFAULT_BACKLOG, 128).
-define(DEFAULT_IDLE_TIMEOUT, 60000).
-define(DEFAULT_MAX_CONNECTIONS, 16384).

%% ═══ lifecycle ═══════════════════════════════════════════════════════════════

%% Every cell calls this first. The cheap path is one `ets:whereis/1`.
%%
%% There is no `rakun.app` file: a sidecar is compiled by `compile:file/2` at run
%% time with no rebar, no release and no code path beyond the output directory
%% (`codegen/erlang.zig`'s `__bp_load_siblings/0`). The application spec is
%% therefore loaded from a term rather than from disk, which is what makes
%% `application:start(rakun)` — and with it the supervision tree — available in a
%% plain `botopink test --target erlang` run.
ensure_started() ->
    case ets:whereis(?PROPS) of
        undefined -> start_app();
        _ -> ok
    end.

start_app() ->
    _ = application:load(app_spec()),
    case application:start(rakun) of
        ok -> ok;
        {error, {already_started, rakun}} -> ok;
        {error, Reason} -> erlang:error({rakun_start, Reason})
    end.

stop_app() ->
    _ = application:stop(rakun),
    _ = application:unload(rakun),
    0.

app_spec() ->
    {application, rakun,
     [{description, "rakun runtime"},
      {vsn, "0.0.1"},
      {modules, [?MODULE]},
      {registered, [rakun_sup, rakun_registry, rakun_conn_sup]},
      {applications, [kernel, stdlib]},
      {mod, {?MODULE, []}}]}.

start(_Type, _Args) ->
    supervisor:start_link({local, rakun_sup}, ?MODULE, sup).

stop(_State) ->
    ok.

start_registry() ->
    gen_server:start_link({local, rakun_registry}, ?MODULE, registry, []).

start_conn_sup() ->
    supervisor:start_link({local, rakun_conn_sup}, ?MODULE, conn_sup).

init(sup) ->
    Flags = #{strategy => one_for_one, intensity => 5, period => 10},
    Registry = #{id => rakun_registry,
                 start => {?MODULE, start_registry, []},
                 restart => permanent, shutdown => 5000,
                 type => worker, modules => [?MODULE]},
    ConnSup = #{id => rakun_conn_sup,
                start => {?MODULE, start_conn_sup, []},
                restart => permanent, shutdown => infinity,
                type => supervisor, modules => [?MODULE]},
    {ok, {Flags, [Registry, ConnSup]}};
init(conn_sup) ->
    Flags = #{strategy => simple_one_for_one, intensity => 0, period => 1},
    Child = #{id => rakun_connection,
              start => {?MODULE, start_connection, []},
              restart => temporary, shutdown => brutal_kill,
              type => worker, modules => [?MODULE]},
    {ok, {Flags, [Child]}};
init(registry) ->
    create_tables(),
    {ok, #{}}.

create_tables() ->
    Common = [named_table, public, {read_concurrency, true}],
    _ = ets:new(?SCAN,     [ordered_set | Common]),
    _ = ets:new(?SINGLE,   [set | Common]),
    _ = ets:new(?BUILDS,   [set, {write_concurrency, true} | Common]),
    _ = ets:new(?PROPS,    [set | Common]),
    _ = ets:new(?ROUTES,   [ordered_set | Common]),
    _ = ets:new(?FAILURES, [set | Common]),
    _ = ets:new(?LOCKS,    [set | Common]),
    seed_failures(),
    ok.

handle_call(_Request, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
handle_info(_Info, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_Old, State, _Extra) -> {ok, State}.

%% ═══ component scan ══════════════════════════════════════════════════════════
%% `runtime.mjs:20-31`. `?SCAN` is an ordered_set keyed by a monotonic sequence,
%% so `scanned_names/0` answers in declaration order the way the node array does.

scan(Name) ->
    ensure_started(),
    _ = append(?SCAN, {Name}),
    0.

scanned_names() ->
    ensure_started(),
    join([N || {_Seq, N} <- ets:tab2list(?SCAN)], <<",">>).

scanned_count() ->
    ensure_started(),
    ets:info(?SCAN, size).

%% ═══ dependency-cycle guard ══════════════════════════════════════════════════
%% `runtime.mjs:40-62`. The stack is per-process because a construction happens
%% inside whichever process asked for it.

enter(Name) ->
    ensure_started(),
    Stack = building(),
    case lists:member(Name, Stack) of
        true -> erlang:error({rakun_cycle, Name});
        false ->
            put(rakun_building, [Name | Stack]),
            _ = ets:update_counter(?BUILDS, Name, {2, 1}, {Name, 0}),
            0
    end.

done(Name) ->
    put(rakun_building, lists:delete(Name, building())),
    0.

building() ->
    case get(rakun_building) of
        undefined -> [];
        Stack -> Stack
    end.

build_count(Name) ->
    ensure_started(),
    case ets:lookup(?BUILDS, Name) of
        [{_, Count}] -> Count;
        [] -> 0
    end.

%% ═══ singleton scope ═════════════════════════════════════════════════════════
%% `runtime.mjs:71-78`, with the BEAM's one difference: many request processes
%% can miss the cache at the same instant. The FIRST construction of a name is
%% serialised by a per-name claim in `?LOCKS` (`insert_new/2`, no message round
%% trip): the claimant builds, every other process waits for the value, so
%% `build_count/1` is 1 however many readers raced. The build runs in the
%% claimant's own process — the cycle guard is its process dictionary — and a
%% claimant that re-enters its own claim (a cycle) builds again, which is where
%% `enter/1` raises `{rakun_cycle, Name}`. A claimant that dies mid-build frees
%% the claim (a waiter monitors it) and the next waiter builds. The value itself
%% still goes in with `insert_new/2`, so one instance per type holds even then.

singleton(Name, Build) ->
    ensure_started(),
    case ets:lookup(?SINGLE, Name) of
        [{_, Value}] -> Value;
        [] -> claim(Name, Build)
    end.

claim(Name, Build) ->
    Self = self(),
    case ets:insert_new(?LOCKS, {Name, Self}) of
        true ->
            try build_once(Name, Build)
            after ets:delete_object(?LOCKS, {Name, Self})
            end;
        false ->
            case ets:lookup(?LOCKS, Name) of
                [{_, Self}] -> build_once(Name, Build);
                [{_, Owner}] -> await_singleton(Name, Build, Owner);
                [] -> singleton(Name, Build)
            end
    end.

build_once(Name, Build) ->
    case ets:lookup(?SINGLE, Name) of
        [{_, Existing}] -> Existing;
        [] ->
            Value = Build(),
            case ets:insert_new(?SINGLE, {Name, Value}) of
                true -> Value;
                false ->
                    [{_, Winner}] = ets:lookup(?SINGLE, Name),
                    Winner
            end
    end.

await_singleton(Name, Build, Owner) ->
    Ref = erlang:monitor(process, Owner),
    Result = await_loop(Name, Ref),
    erlang:demonitor(Ref, [flush]),
    case Result of
        {ok, Value} -> Value;
        retry -> singleton(Name, Build)
    end.

await_loop(Name, Ref) ->
    case ets:lookup(?SINGLE, Name) of
        [{_, Value}] -> {ok, Value};
        [] ->
            case ets:member(?LOCKS, Name) of
                false -> retry;
                true ->
                    receive
                        {'DOWN', Ref, process, _, _} -> retry
                    after 1 -> await_loop(Name, Ref)
                    end
            end
    end.

%% ═══ properties ══════════════════════════════════════════════════════════════
%% `runtime.mjs:84-97`. `prop/1` answers `""` for an absent key and `prop_int/1`
%% answers `0` for an absent or unparsable one — `#[value("key")]` fields depend
%% on both. `prop_int/1` is JavaScript's `parseInt(v, 10)`: a leading integer
%% wins ("12abc" is 12), a value with no leading integer is 0.

set_prop(Key, Value) ->
    ensure_started(),
    true = ets:insert(?PROPS, {Key, Value}),
    0.

prop(Key) ->
    ensure_started(),
    case ets:lookup(?PROPS, Key) of
        [{_, Value}] -> Value;
        [] -> <<>>
    end.

prop_int(Key) ->
    parse_int(prop(Key)).

parse_int(Bin) when is_binary(Bin) ->
    case string:to_integer(string:trim(Bin, leading)) of
        {error, _} -> 0;
        {Int, _Rest} -> Int
    end;
parse_int(_) ->
    0.

%% `prop/1` with a default for a key nothing has set — the tuning keys below.
prop_int_default(Key, Default) ->
    case prop(Key) of
        <<>> -> Default;
        Raw -> case parse_int(Raw) of 0 -> Default; N -> N end
    end.

%% ═══ router ══════════════════════════════════════════════════════════════════
%% `runtime.mjs:107-196`. A route row keeps the authored path beside its split
%% segments because `route_paths/0` answers the authored spelling.

register_route(Verb, Path, Handler) ->
    ensure_started(),
    _ = append(?ROUTES, {Verb, Path, split(Path), Handler}),
    0.

route_count() ->
    ensure_started(),
    ets:info(?ROUTES, size).

route_paths() ->
    ensure_started(),
    join([<<V/binary, " ", P/binary>> || {_Seq, V, P, _Segs, _H} <- ets:tab2list(?ROUTES)],
         <<", ">>).

split(Path) ->
    [S || S <- binary:split(Path, <<"/">>, [global]), S =/= <<>>].

%% Registration order decides between two routes that both match: `?ROUTES` is an
%% ordered_set on the sequence, so `tab2list/1` is already in that order.
match(Verb, Path) ->
    find_route(Verb, split(Path), ets:tab2list(?ROUTES)).

find_route(_Verb, _Want, []) ->
    nomatch;
find_route(Verb, Want, [{_Seq, RVerb, _RPath, RSegs, Handler} | Rest]) ->
    case RVerb =:= Verb andalso length(RSegs) =:= length(Want) of
        false -> find_route(Verb, Want, Rest);
        true ->
            case bind(RSegs, Want, #{}) of
                {ok, Params} -> {ok, Handler, Params};
                nomatch -> find_route(Verb, Want, Rest)
            end
    end.

bind([], [], Params) ->
    {ok, Params};
bind([<<":", Name/binary>> | RSegs], [Got | Want], Params) ->
    bind(RSegs, Want, Params#{Name => Got});
bind([Seg | RSegs], [Seg | Want], Params) ->
    bind(RSegs, Want, Params);
bind(_, _, _) ->
    nomatch.

%% The value a handler receives. `runtime.mjs:146-161` builds an object with a
%% method/path field and four closures; the erlang twin is a map carrying the
%% same six pieces, and `param`/`query`/`header` answer `<<>>` — never
%% `undefined` — because `src/http.bp:30-34` fixes the contract at plain
%% `string`. The erlang backend dispatches a method a `behavior` declares
%% without a body through the value itself — `(maps:get(param, Req))(Req, N)` —
%% so the four methods are funs under their own names, each taking the receiver
%% first. The data sits under `params` / `query_map` / `headers` / `body_bin`,
%% never under a method's name.
request(Verb, Path, Params, Query, Headers, Body) ->
    #{method => Verb, path => Path, params => Params,
      query_map => Query, headers => Headers, body_bin => Body,
      param => fun(_Self, N) -> lookup(N, Params) end,
      query => fun(_Self, N) -> lookup(N, Query) end,
      header => fun(_Self, N) -> lookup(string:lowercase(to_binary(N)), Headers) end,
      body => fun(_Self) -> Body end}.

lookup(Name, Map) ->
    case maps:find(to_binary(Name), Map) of
        {ok, V} -> to_binary(V);
        error -> <<>>
    end.

%% In-process dispatch (`runtime.mjs:166-171`): path params bound, everything
%% else empty. This is the seam `test/router_test.bp` drives.
dispatch(Verb, Path) ->
    ensure_started(),
    case match(Verb, Path) of
        nomatch -> not_found();
        {ok, Handler, Params} ->
            Handler(request(Verb, Path, Params, #{}, #{}, <<>>))
    end.

%% The real-server seam (`runtime.mjs:188-196`), plus THE ONE HOOK other fronts
%% hang off. `Rakun.run` is frozen and hardcodes this dispatcher
%% (`src/bootstrap.bp:33-35`), so no later front can wrap the request path from
%% outside; front 07's filter chain, CORS, compression, error handling and API
%% versioning all enter through `rakun_chain:run/6`, and front 10's security
%% filter and front 11's request metrics enter through front 07's chain rather
%% than through a second hook. With rakun-web out of the build the branch is
%% never taken and the cost is one `function_exported/3` per request.
dispatch_http(Verb, Path, HeadersJson, QueryJson, Body) ->
    ensure_started(),
    case erlang:function_exported(rakun_chain, run, 6) of
        true -> rakun_chain:run(Verb, Path, HeadersJson, QueryJson, Body, fun handle/6);
        false -> handle(Verb, Path, HeadersJson, QueryJson, Body, undefined)
    end.

handle(Verb, Path, HeadersJson, QueryJson, Body, _Chain) ->
    case match(Verb, Path) of
        nomatch -> not_found();
        {ok, Handler, Params} ->
            Headers = lower_keys(decode_object(HeadersJson)),
            Handler(request(Verb, Path, Params, decode_object(QueryJson), Headers, Body))
    end.

not_found() ->
    #{status => 404, body => <<>>}.

%% ═══ reply headers ═══════════════════════════════════════════════════════════
%% `Response` is `(status: i32, body: string)` and `src/http.bp` is frozen, so
%% there is no field for a header and no `withHeader` to add one. A request is a
%% process, so the reply headers for the in-flight request are process-local: a
%% request that sets none pays nothing, and two requests never see each other's.
%% A second write to the same name replaces the first (case-insensitively); the
%% spelling that reaches the wire is the last one written.

set_reply_header(Name, Value) ->
    Key = lower(Name),
    Kept = [H || {K, _N, _V} = H <- reply_list(), K =/= Key],
    put(rakun_reply_headers, Kept ++ [{Key, Name, Value}]),
    0.

%% Built by hand rather than through a map so the object keeps INSERTION order:
%% a map's key order is not the write order, and a caller that writes the
%% headers to a wire — or a test that asserts the string — needs the order it
%% asked for. `json:encode/1` still does the escaping, one value at a time.
reply_headers_json() ->
    Pairs = [[json:encode(N), <<":">>, json:encode(V)] || {_K, N, V} <- reply_list()],
    iolist_to_binary([<<"{">>, lists:join(<<",">>, Pairs), <<"}">>]).

clear_reply_headers() ->
    erase(rakun_reply_headers),
    0.

reply_list() ->
    case get(rakun_reply_headers) of
        undefined -> [];
        List -> List
    end.

%% ═══ boot options ════════════════════════════════════════════════════════════
%% `App(port, basePath)` is frozen, so the boot options Spring carries on
%% `SpringApplication` are configuration keys — `rakun.main.banner-mode`,
%% `rakun.main.headless`, `rakun.main.keep-alive`, `rakun.main.pid-file`,
%% `rakun.main.port-file`, `rakun.server.backlog`, `rakun.server.idle-timeout`,
%% `rakun.server.max-connections`, `rakun.server.transport` — fed by front 05
%% once it lands. `boot/1` is the escape hatch for a program that would rather
%% set them in code than in a file: it writes the SAME properties, so there is
%% exactly one resolution path and configuration still wins or loses by front
%% 05's ordering.

boot(OptionsJson) ->
    ensure_started(),
    maps:foreach(fun(K, V) -> set_prop(K, to_binary(V)) end, decode_object(OptionsJson)),
    print_banner(),
    write_pid_file(),
    0.

print_banner() ->
    case prop(<<"rakun.main.banner-mode">>) of
        <<"off">> -> ok;
        _ ->
            case in_test_run() of
                true -> ok;   %% a banner never pollutes assertion output
                false -> io:put_chars(banner_text())
            end
    end.

%% `banner.txt` from the working directory, with the three substitutions; a
%% one-line default when there is no file.
banner_text() ->
    Otp = list_to_binary(erlang:system_info(otp_release)),
    Vsn = prop_or(<<"application.version">>, <<"0.0.0">>),
    Rk = prop_or(<<"rakun.version">>, <<"0.0.1">>),
    case file:read_file("banner.txt") of
        {ok, Raw} ->
            Subs = [{<<"${application.version}">>, Vsn},
                    {<<"${rakun.version}">>, Rk},
                    {<<"${otp.version}">>, Otp}],
            lists:foldl(fun({From, To}, Acc) ->
                                binary:replace(Acc, From, To, [global])
                        end, Raw, Subs);
        {error, _} ->
            <<"rakun ", Rk/binary, " (application ", Vsn/binary, ", OTP ", Otp/binary, ")\n">>
    end.

prop_or(Key, Default) ->
    case prop(Key) of
        <<>> -> Default;
        Value -> Value
    end.

%% A test run is an escript whose module carries the emitted test runner; the
%% banner is suppressed there whatever `banner-mode` says.
in_test_run() ->
    erlang:function_exported(?MODULE, no_such_function, 0) orelse
        lists:any(fun({Mod, _}) -> erlang:function_exported(Mod, '__bp_run_tests', 1) end,
                  code:all_loaded()).

write_pid_file() ->
    case prop(<<"rakun.main.pid-file">>) of
        <<>> -> ok;
        Path -> _ = file:write_file(Path, list_to_binary(os:getpid())), ok
    end.

write_port_file(Port) ->
    case prop(<<"rakun.main.port-file">>) of
        <<>> -> ok;
        Path -> _ = file:write_file(Path, integer_to_binary(Port)), ok
    end.

remove_pid_file() ->
    case prop(<<"rakun.main.pid-file">>) of
        <<>> -> ok;
        Path -> _ = file:delete(Path), ok
    end.

%% ═══ startup failure diagnostics ═════════════════════════════════════════════
%% Spring's `FailureAnalyzer` turns a stack trace into a description and an
%% action. rakun's version is a table keyed by the error term, consulted before
%% the node halts. It is DATA: front 08 adds the bad-DB-URL row through
%% `add_failure/3` without editing this module.

seed_failures() ->
    Rows =
        [{listen_eaddrinuse,
          <<"The configured port is already bound.">>,
          <<"Set `rakun.server.port` to a free port, or identify the holder "
            "(`ss -ltnp | grep :<port>`) and stop it.">>},
         {listen_eacces,
          <<"Binding a privileged port without the capability.">>,
          <<"Use a port above 1024, or grant CAP_NET_BIND_SERVICE to the BEAM.">>},
         {rakun_cycle,
          <<"A component depends transitively on itself.">>,
          <<"Break the cycle, or move one edge behind a setter. "
            "The construction stack is printed innermost last.">>},
         {missing_property,
          <<"A #[value(\"key\")] field has no value and no default.">>,
          <<"Set the key in a property source, or give the field a default.">>},
         {transport,
          <<"An unknown or unloadable transport.">>,
          <<"Set `rakun.server.transport` to `gen_tcp` (the default) or to a "
            "transport whose adapter module is on the code path.">>}],
    [ets:insert(?FAILURES, Row) || Row <- Rows],
    ok.

add_failure(Term, Description, Action) ->
    ensure_started(),
    true = ets:insert(?FAILURES, {failure_key(Term), Description, Action}),
    0.

%% The key a term is looked up under: `{listen, eaddrinuse}` → `listen_eaddrinuse`,
%% `{rakun_cycle, "A"}` → `rakun_cycle`. A term with no row is not diagnosed.
failure_key(Term) when is_atom(Term) ->
    Term;
failure_key({listen, Reason, _Port}) when is_atom(Reason) ->
    list_to_atom("listen_" ++ atom_to_list(Reason));
failure_key(Term) when is_tuple(Term), tuple_size(Term) >= 1 ->
    case element(1, Term) of
        Tag when is_atom(Tag) -> Tag;
        _ -> unknown
    end;
failure_key(_) ->
    unknown.

%% Three blocks — the error, a description, an action — as an iolist. An
%% unmatched error prints the raw term and says no diagnosis is available: it
%% does not guess.
diagnose(Term) ->
    Head = io_lib:format("rakun failed to start~n  error:       ~p~n", [Term]),
    Body =
        case ets:lookup(?FAILURES, failure_key(Term)) of
            [{_, Description, Action}] ->
                io_lib:format("  description: ~s~n  action:      ~s~n", [Description, Action]);
            [] ->
                io_lib:format("  description: no diagnosis is available for this error.~n"
                              "  action:      report the term above.~n", [])
        end,
    %% The one piece a table row cannot carry: the value the failing call was
    %% given. A diagnosis that says "the port is already bound" without naming
    %% the port has not saved anybody a grep.
    Extra =
        case Term of
            {rakun_cycle, _} ->
                io_lib:format("  building:    ~p (innermost last)~n", [lists:reverse(building())]);
            {listen, _, Port} ->
                io_lib:format("  port:        ~p  (`rakun.server.port`)~n", [Port]);
            {transport, Name} ->
                io_lib:format("  value:       ~s~n  module:      rakun_~s~n", [Name, Name]);
            _ ->
                []
        end,
    iolist_to_binary([Head, Body, Extra]).

fail(Term) ->
    io:put_chars(standard_error, diagnose(Term)),
    erlang:halt(1).

%% ═══ the gen_tcp acceptor ════════════════════════════════════════════════════
%% `runtime.mjs:206-231` is `node:http`'s `createServer`. The BEAM's answer is
%% `gen_tcp` with `{packet, http_bin}`: OTP decodes the request line and the
%% headers itself, so rakun writes no HTTP parser and depends on nothing outside
%% `kernel`. Cowboy is NOT used — a sidecar is compiled by `compile:file/2` with
%% no rebar and no code path, so `cowboy:start_clear/3` would compile fine and
%% then die with `undefined function` on every machine that has not separately
%% installed cowboy. It stays available as an adapter: `rakun.server.transport`.
%%
%% One process per connection, under `rakun_conn_sup` (`simple_one_for_one`,
%% temporary children): a handler that throws kills its own connection process
%% and nothing else — the BEAM answer to `runtime.mjs:222-224`'s try/catch.

serve(Port, Dispatcher) ->
    ensure_started(),
    case prop(<<"rakun.main.headless">>) of
        <<"true">> ->
            keep_alive_or_return(0);
        _ ->
            Bound = listen(Port, Dispatcher),
            write_port_file(Bound),
            keep_alive_or_return(Bound)
    end.

listen(Port, Dispatcher) ->
    case transport() of
        gen_tcp ->
            Spec = #{id => rakun_listener,
                     start => {?MODULE, start_listener, [Port, Dispatcher]},
                     restart => permanent, shutdown => 5000,
                     type => worker, modules => [?MODULE]},
            _ = supervisor:terminate_child(rakun_sup, rakun_listener),
            _ = supervisor:delete_child(rakun_sup, rakun_listener),
            case supervisor:start_child(rakun_sup, Spec) of
                {ok, _Pid} -> bound_port();
                {error, {Reason, _}} -> fail(Reason);
                {error, Reason} -> fail(Reason)
            end;
        {adapter, Module} ->
            Module:serve(Port, Dispatcher)
    end.

%% `rakun.server.transport` unset (or `gen_tcp`) is the acceptor. A named
%% transport whose adapter module cannot be loaded is a startup FAILURE naming
%% the module — never a silent fall back to the acceptor.
transport() ->
    case prop(<<"rakun.server.transport">>) of
        <<>> -> gen_tcp;
        <<"gen_tcp">> -> gen_tcp;
        Name ->
            Module = binary_to_atom(<<"rakun_", Name/binary>>, utf8),
            case code:ensure_loaded(Module) of
                {module, Module} -> {adapter, Module};
                {error, _} -> fail({transport, Name})
            end
    end.

%% The acceptor process owns the listening socket, so a restart rebinds it
%% rather than inheriting a socket whose controlling process is gone. The bound
%% port goes into `?PROPS` before the loop starts, so `serve/2` can answer it
%% even when `port: 0` asked for an ephemeral one.
start_listener(Port, Dispatcher) ->
    Backlog = prop_int_default(<<"rakun.server.backlog">>, ?DEFAULT_BACKLOG),
    Opts = [binary, {packet, http_bin}, {active, false},
            {reuseaddr, true}, {backlog, Backlog}],
    case gen_tcp:listen(Port, Opts) of
        {ok, LSock} ->
            {ok, Bound} = inet:port(LSock),
            _ = set_prop(<<"rakun.server.bound-port">>, integer_to_binary(Bound)),
            {ok, proc_lib:spawn_link(fun() -> accept_loop(LSock, Dispatcher) end)};
        {error, Reason} ->
            {error, {listen, Reason, Port}}
    end.

bound_port() ->
    prop_int(<<"rakun.server.bound-port">>).

accept_loop(LSock, Dispatcher) ->
    case gen_tcp:accept(LSock) of
        {ok, Sock} ->
            case over_capacity() of
                true ->
                    _ = gen_tcp:send(Sock, [<<"HTTP/1.1 503 Service Unavailable\r\n">>,
                                            <<"Content-Length: 0\r\n">>,
                                            <<"Connection: close\r\n\r\n">>]),
                    _ = gen_tcp:close(Sock);
                false ->
                    case supervisor:start_child(rakun_conn_sup, [Sock, Dispatcher]) of
                        {ok, Pid} -> _ = gen_tcp:controlling_process(Sock, Pid);
                        _ -> _ = gen_tcp:close(Sock)
                    end
            end,
            accept_loop(LSock, Dispatcher);
        {error, closed} ->
            ok;
        {error, _Reason} ->
            accept_loop(LSock, Dispatcher)
    end.

over_capacity() ->
    Max = prop_int_default(<<"rakun.server.max-connections">>, ?DEFAULT_MAX_CONNECTIONS),
    Counts = supervisor:count_children(rakun_conn_sup),
    proplists:get_value(active, Counts, 0) >= Max.

start_connection(Sock, Dispatcher) ->
    {ok, proc_lib:spawn_link(?MODULE, connection, [Sock, Dispatcher])}.

connection(Sock, Dispatcher) ->
    receive after 0 -> ok end,   %% let `controlling_process/2` land first
    serve_requests(Sock, Dispatcher).

serve_requests(Sock, Dispatcher) ->
    Idle = prop_int_default(<<"rakun.server.idle-timeout">>, ?DEFAULT_IDLE_TIMEOUT),
    _ = clear_reply_headers(),
    case read_request(Sock, Idle) of
        {ok, Verb, Path, Headers} ->
            Body = read_body(Sock, Headers, Idle),
            {RawPath, Query} = split_query(Path),
            Response = run_handler(Dispatcher, Verb, RawPath, Headers, Query, Body),
            KeepAlive = write_response(Sock, Response),
            _ = clear_reply_headers(),
            case KeepAlive of
                true -> serve_requests(Sock, Dispatcher);
                false -> gen_tcp:close(Sock)
            end;
        _ ->
            gen_tcp:close(Sock)
    end.

read_request(Sock, Idle) ->
    _ = inet:setopts(Sock, [{packet, http_bin}]),
    case gen_tcp:recv(Sock, 0, Idle) of
        {ok, {http_request, Method, {abs_path, Path}, _Version}} ->
            case read_headers(Sock, Idle, #{}) of
                {ok, Headers} -> {ok, verb(Method), Path, Headers};
                Other -> Other
            end;
        {ok, _Other} ->
            {error, bad_request};
        {error, Reason} ->
            {error, Reason}
    end.

read_headers(Sock, Idle, Acc) ->
    case gen_tcp:recv(Sock, 0, Idle) of
        {ok, {http_header, _, Field, _, Value}} ->
            read_headers(Sock, Idle, Acc#{lower(to_binary(Field)) => to_binary(Value)});
        {ok, http_eoh} ->
            {ok, Acc};
        {ok, _Other} ->
            {error, bad_request};
        {error, Reason} ->
            {error, Reason}
    end.

%% A body is read in `{packet, raw}` by its `Content-Length`, so a body that
%% happens to contain `\r\n\r\n` arrives intact.
read_body(Sock, Headers, Idle) ->
    case parse_int(maps:get(<<"content-length">>, Headers, <<"0">>)) of
        0 -> <<>>;
        Len ->
            _ = inet:setopts(Sock, [{packet, raw}]),
            case gen_tcp:recv(Sock, Len, Idle) of
                {ok, Body} -> Body;
                {error, _} -> <<>>
            end
    end.

verb(Method) when is_atom(Method) -> atom_to_binary(Method, utf8);
verb(Method) -> to_binary(Method).

%% A repeated query key takes the FIRST occurrence, as `runtime.mjs:212` does.
split_query(Path) ->
    case binary:split(Path, <<"?">>) of
        [Raw] -> {Raw, #{}};
        [Raw, Rest] -> {Raw, query_map(binary:split(Rest, <<"&">>, [global]), #{})}
    end.

query_map([], Acc) ->
    Acc;
query_map([Pair | Rest], Acc) ->
    Next =
        case binary:split(Pair, <<"=">>) of
            [<<>>] -> Acc;
            [Key] -> maps:merge(#{unescape(Key) => <<>>}, Acc);
            [Key, Value] -> maps:merge(#{unescape(Key) => unescape(Value)}, Acc)
        end,
    query_map(Rest, Next).

%% `maps:merge/2` with the accumulator second keeps the first occurrence.
unescape(Bin) ->
    unescape(Bin, <<>>).

unescape(<<$%, A, B, Rest/binary>>, Acc) ->
    try binary_to_integer(<<A, B>>, 16) of
        Byte -> unescape(Rest, <<Acc/binary, Byte>>)
    catch
        _:_ -> unescape(Rest, <<Acc/binary, $%, A, B>>)
    end;
unescape(<<$+, Rest/binary>>, Acc) ->
    unescape(Rest, <<Acc/binary, $\s>>);
unescape(<<C, Rest/binary>>, Acc) ->
    unescape(Rest, <<Acc/binary, C>>);
unescape(<<>>, Acc) ->
    Acc.

%% A handler that raises answers 500 with the reason as the body and the
%% connection process carries on — the next request on a fresh connection is
%% unaffected because it is a different process.
run_handler(Dispatcher, Verb, Path, Headers, Query, Body) ->
    HeadersJson = iolist_to_binary(json:encode(Headers)),
    QueryJson = iolist_to_binary(json:encode(Query)),
    try Dispatcher(Verb, Path, HeadersJson, QueryJson, Body) of
        Response -> response_parts(Response)
    catch
        Class:Reason ->
            #{status => 500,
              body => iolist_to_binary(io_lib:format("~p:~p", [Class, Reason]))}
    end.

%% A handler's `Response` reaches the acceptor as the record the erlang backend
%% lowers it to (decision 21: `{'rakun@http@@Response', Status, Body}`); a host
%% path — `not_found/0`, the 500 above — builds the `#{status, body}` map the
%% declaration boundary adopts. The acceptor reads either.
response_parts(#{status := Status, body := Body}) ->
    #{status => Status, body => Body};
response_parts(Record) when is_tuple(Record), tuple_size(Record) =:= 3 ->
    #{status => element(2, Record), body => element(3, Record)}.

write_response(Sock, #{status := Status, body := Body}) ->
    Extra = [[N, <<": ">>, V, <<"\r\n">>] || {_K, N, V} <- reply_list()],
    Head = [<<"HTTP/1.1 ">>, integer_to_binary(Status), <<" ">>, reason_phrase(Status),
            <<"\r\nContent-Length: ">>, integer_to_binary(byte_size(Body)),
            <<"\r\nConnection: keep-alive\r\n">>],
    case gen_tcp:send(Sock, [Head, Extra, <<"\r\n">>, Body]) of
        ok -> true;
        {error, _} -> false
    end.

reason_phrase(200) -> <<"OK">>;
reason_phrase(201) -> <<"Created">>;
reason_phrase(400) -> <<"Bad Request">>;
reason_phrase(404) -> <<"Not Found">>;
reason_phrase(500) -> <<"Internal Server Error">>;
reason_phrase(503) -> <<"Service Unavailable">>;
reason_phrase(_) -> <<"OK">>.

%% `serve/2` blocks. On node the listening socket keeps the event loop alive; on
%% the BEAM the escript's `main/1` returning halts the node, so the wait is what
%% keeps a bound listener — or a headless, scheduler-only app — up. The socket is
%% already supervised by the time the wait begins, so a crash in the acceptor is
%% restarted rather than losing the port. `rakun.main.keep-alive=false` is the
%% CI smoke shape: boot, do whatever `main` does, and return the bound port.
keep_alive_or_return(Bound) ->
    case prop(<<"rakun.main.keep-alive">>) of
        <<"false">> ->
            _ = remove_pid_file(),
            Bound;
        _ ->
            receive after infinity -> Bound end
    end.

%% ═══ small helpers ═══════════════════════════════════════════════════════════

%% Append under a monotonic sequence. `?SCAN` and `?ROUTES` are append-only, so
%% the table's size is the next free key; `insert_new/2` makes two processes
%% appending at the same instant take different keys rather than clobber.
append(Table, Tuple) ->
    Seq = ets:info(Table, size),
    case ets:insert_new(Table, erlang:insert_element(1, Tuple, Seq)) of
        true -> Seq;
        false -> append(Table, Tuple)
    end.

join([], _Sep) -> <<>>;
join(Parts, Sep) -> iolist_to_binary(lists:join(Sep, Parts)).

lower(Bin) when is_binary(Bin) -> string:lowercase(Bin);
lower(Other) -> string:lowercase(to_binary(Other)).

lower_keys(Map) ->
    maps:fold(fun(K, V, Acc) -> Acc#{lower(to_binary(K)) => to_binary(V)} end, #{}, Map).

to_binary(Bin) when is_binary(Bin) -> Bin;
to_binary(Atom) when is_atom(Atom) -> atom_to_binary(Atom, utf8);
to_binary(Int) when is_integer(Int) -> integer_to_binary(Int);
to_binary(Float) when is_float(Float) -> float_to_binary(Float, [short]);
to_binary(List) when is_list(List) -> iolist_to_binary(List).

%% A malformed or empty JSON object answers `#{}` — `runtime.mjs:178-186`.
decode_object(<<>>) ->
    #{};
decode_object(Json) when is_binary(Json) ->
    try json:decode(Json) of
        Map when is_map(Map) -> Map;
        _ -> #{}
    catch
        _:_ -> #{}
    end;
decode_object(_) ->
    #{}.
