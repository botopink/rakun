%%% rakun-actuator — availability state, the listener role and the response
%%% sanitizer (front 76).
%%%
%%% READINESS is `refusing` until front 06's `ApplicationReady` and again from
%%% the moment `readiness_drained/0` runs — front 07's graceful shutdown calls
%%% it FIRST, and it returns only after `rakun.lifecycle.pre-drain-period`
%%% (default 5000 ms) has elapsed in full, so the load balancer sees the probe
%%% fail before the socket stops accepting. LIVENESS is `correct` unless the
%%% application sets it `broken`.
%%%
%%% THE ROLE is per connection process: the management listener's dispatcher
%%% marks its process `management`, so one route table can tell which listener
%%% a request arrived on.
%%%
%%% THE SANITIZER walks an endpoint's JSON body and replaces the `value` of
%%% every object carrying `key` and `value` — `env` and `configprops` share
%%% it. A key matching a pattern is always `******`; the others follow
%%% `show-values`.

-module(rakun_probes).
-export([readiness/0, set_readiness/1, liveness/0, set_liveness/1, readiness_drained/0,
         refusing_since/0, role/0, set_role/1, sanitize/4, authorities/0,
         filter_put/1, filter_apply/2, now_ms/0, reset/0,
         env_json/0, prop_keys/1, warn/1, warnings/0, later/2, test_authorities/1]).

readiness() -> persistent_term:get(rakun_probes_readiness, <<"REFUSING_TRAFFIC">>).

set_readiness(true) -> persistent_term:put(rakun_probes_readiness, <<"ACCEPTING_TRAFFIC">>), 0;
set_readiness(false) ->
    case readiness() of
        <<"REFUSING_TRAFFIC">> -> ok;
        _ -> persistent_term:put(rakun_probes_refusing_since, now_ms())
    end,
    persistent_term:put(rakun_probes_readiness, <<"REFUSING_TRAFFIC">>),
    0.

liveness() -> persistent_term:get(rakun_probes_liveness, <<"CORRECT">>).

set_liveness(true) -> persistent_term:put(rakun_probes_liveness, <<"CORRECT">>), 0;
set_liveness(false) -> persistent_term:put(rakun_probes_liveness, <<"BROKEN">>), 0.

refusing_since() -> persistent_term:get(rakun_probes_refusing_since, 0).

%% Front 07's first shutdown step: readiness false NOW, then the whole
%% pre-drain window, even when nothing is in flight.
readiness_drained() ->
    persistent_term:put(rakun_probes_readiness, <<"REFUSING_TRAFFIC">>),
    At = now_ms(),
    persistent_term:put(rakun_probes_refusing_since, At),
    Period = case rakun_runtime:prop(<<"rakun.lifecycle.pre-drain-period">>) of
                 <<>> -> 5000;
                 P -> try binary_to_integer(P) catch _:_ -> 5000 end
             end,
    case Period > 0 of
        true -> timer:sleep(Period);
        false -> ok
    end,
    At.

role() ->
    case get(rakun_listener_role) of
        undefined -> <<"server">>;
        R -> R
    end.

set_role(R) -> put(rakun_listener_role, R), 0.

%% The caller's authorities from front 10's context, `[]` without one.
authorities() ->
    case erlang:function_exported(rakun_security, wire, 0) of
        true ->
            case binary:split(rakun_security:wire(), <<"\t">>, [global]) of
                [_, _, _, List | _] when List =/= <<>> -> binary:split(List, <<",">>, [global]);
                _ -> []
            end;
        false ->
            case get(rakun_probes_test_authorities) of
                undefined -> [];
                L -> L
            end
    end.

%% `Mode` never | always | when-authorized; `Authorized` true when the caller
%% holds a required role; `Patterns` the lowercase substrings that mark a key.
sanitize(Json, Mode, Authorized, Patterns) ->
    Show = case Mode of
               <<"always">> -> true;
               <<"when-authorized">> -> Authorized;
               _ -> false
           end,
    try json:decode(Json) of
        Term -> iolist_to_binary(json:encode(walk(Term, Show, Patterns)))
    catch _:_ -> Json
    end.

walk(#{<<"key">> := K, <<"value">> := _} = M, Show, Patterns) ->
    Hidden = (not Show) orelse sensitive(K, Patterns),
    M1 = case Hidden of
             true -> M#{<<"value">> => <<"******">>};
             false -> M
         end,
    maps:map(fun(<<"value">>, V) -> V; (_, V) -> walk(V, Show, Patterns) end, M1);
walk(M, Show, Patterns) when is_map(M) -> maps:map(fun(_, V) -> walk(V, Show, Patterns) end, M);
walk(L, Show, Patterns) when is_list(L) -> [walk(X, Show, Patterns) || X <- L];
walk(X, _, _) -> X.

sensitive(K, Patterns) when is_binary(K) ->
    Low = string:lowercase(K),
    lists:any(fun(P) -> P =/= <<>> andalso binary:match(Low, P) =/= nomatch end, Patterns);
sensitive(_, _) -> false.

%% The endpoint response filter front 11's host applies before rendering.
filter_put(F) -> persistent_term:put(rakun_probes_filter, F), 0.

filter_apply(Id, Body) ->
    case persistent_term:get(rakun_probes_filter, undefined) of
        undefined -> Body;
        F -> try F(Id, Body) catch _:_ -> Body end
    end.

now_ms() -> erlang:monotonic_time(millisecond).

reset() ->
    _ = persistent_term:erase(rakun_probes_readiness),
    _ = persistent_term:erase(rakun_probes_liveness),
    _ = persistent_term:erase(rakun_probes_refusing_since),
    0.

%% `{"properties":[{"key":K,"value":V}, …]}` for every non-empty property,
%% sorted by key — the `env` endpoint's body before sanitization.
env_json() ->
    _ = rakun_runtime:ensure_started(),
    Rows = lists:sort([{K, V} || {K, V} <- ets:tab2list(rakun_props), is_binary(K), is_binary(V), V =/= <<>>]),
    iolist_to_binary(json:encode(#{properties => [#{key => K, value => V} || {K, V} <- Rows]})).

%% Every property key starting with `Prefix` whose value is not empty, sorted.
prop_keys(Prefix) ->
    _ = rakun_runtime:ensure_started(),
    N = byte_size(Prefix),
    lists:sort([K || {K, V} <- ets:tab2list(rakun_props), is_binary(K), V =/= <<>>, byte_size(K) > N,
                     binary:longest_common_prefix([K, Prefix]) =:= N]).

warn(Text) ->
    persistent_term:put(rakun_probes_warnings, warnings() ++ [Text]),
    logger:warning("~ts", [Text]),
    0.

warnings() -> persistent_term:get(rakun_probes_warnings, []).

%% Runs `F` in a fresh process after `Ms` — the shutdown endpoint answers first.
later(Ms, F) ->
    _ = spawn(fun() -> timer:sleep(Ms), F() end),
    0.

%% Test seam: the authorities `authorities/0` answers in this process when
%% front 10 is not in the build.
test_authorities(List) -> put(rakun_probes_test_authorities, List), 0.
