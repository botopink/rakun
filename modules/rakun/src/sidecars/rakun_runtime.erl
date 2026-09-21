%%% rakun — the host runtime on the BEAM: the erlang twin of `src/runtime.mjs`.
%%%
%%% botopink is immutable-first and has no top-level mutable state, so rakun's
%%% runtime state — the component scan registry, the dependency-cycle guard,
%%% the singleton cache, the property map and the router table — lives in the
%%% host, reached from `src/runtime.bp` through `#[@External.Erlang(…)]`
%%% declarations. This module is the erlang half of that seam; `runtime.mjs` is
%%% the node half. Both rows answer the same cells with the same values.
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
%%% STORAGE. Five `named_table, public` ETS tables owned by the `rakun_registry`
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
         dispatch/2, dispatch_http/5]).

%% ── lifecycle, reachable for a test or a later front ─────────────────────────
-export([ensure_started/0, stop_app/0]).

%% ── application callback ─────────────────────────────────────────────────────
-export([start/2, stop/1]).

%% ── supervisor + gen_server callbacks (see ONE MODULE, THREE OTP ROLES) ──────
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% ── supervised entry points ──────────────────────────────────────────────────
-export([start_registry/0]).

-define(SCAN,     rakun_scan).        %% ordered_set: {Seq, Name}
-define(SINGLE,   rakun_singletons).  %% set:         {Name, Value}
-define(BUILDS,   rakun_builds).      %% set:         {Name, Count}
-define(PROPS,    rakun_props).       %% set:         {Key, Value}
-define(ROUTES,   rakun_routes).      %% ordered_set: {Seq, Verb, Path, Segs, Handler}

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
      {registered, [rakun_sup, rakun_registry]},
      {applications, [kernel, stdlib]},
      {mod, {?MODULE, []}}]}.

start(_Type, _Args) ->
    supervisor:start_link({local, rakun_sup}, ?MODULE, sup).

stop(_State) ->
    ok.

start_registry() ->
    gen_server:start_link({local, rakun_registry}, ?MODULE, registry, []).

init(sup) ->
    Flags = #{strategy => one_for_one, intensity => 5, period => 10},
    Registry = #{id => rakun_registry,
                 start => {?MODULE, start_registry, []},
                 restart => permanent, shutdown => 5000,
                 type => worker, modules => [?MODULE]},
    {ok, {Flags, [Registry]}};
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
%% `runtime.mjs:71-78`, with the BEAM's one difference: two request processes can
%% miss the cache at the same instant, so the insert is `insert_new/2` and the
%% loser discards its value. "One instance per type" stays true without a lock;
%% `build_count/1` is then 1 or 2, never a function of the number of readers.

singleton(Name, Build) ->
    ensure_started(),
    case ets:lookup(?SINGLE, Name) of
        [{_, Value}] -> Value;
        [] ->
            Value = Build(),
            case ets:insert_new(?SINGLE, {Name, Value}) of
                true -> Value;
                false ->
                    [{_, Winner}] = ets:lookup(?SINGLE, Name),
                    Winner
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
%% `string`. `request_param/2` and friends are the accessors the emitted handler
%% reaches once erlang-backend behaviour dispatch lands (see AGENTS.md § Blocked).
request(Verb, Path, Params, Query, Headers, Body) ->
    #{method => Verb, path => Path, params => Params,
      query => Query, headers => Headers, body => Body}.

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
