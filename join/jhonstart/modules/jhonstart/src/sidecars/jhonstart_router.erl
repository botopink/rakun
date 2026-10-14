%% jhonstart — the router's host half on the BEAM (front 26).
%%
%% The erlang twin of `../router_runtime.mjs`, cell for cell, so that
%% `test/router_test.bp` is ONE set of assertions run on both rows — the only
%% statement about a port worth making.
%%
%% The store is the calling process's dictionary, which is what a server render
%% wants: a request is a process, the snapshot dies with it, and two concurrent
%% renders cannot see each other's route. Nothing here is a supervised name, an
%% ETS table or an application — a router that outlives its request is a router
%% that answers the previous reader's question.
%%
%% This module parses nothing and matches nothing. The five values arrive
%% already encoded exactly as front 23's payload carries them (`p`, `m`, `q`,
%% `r`, plus the per-layout `selected`); the matcher and the route table are
%% front 22's and are compiled once, not twice.
%%
%% The module atom may not be `router`: `shipErlSidecars` skips an atom that
%% matches a module the build emitted, and the skip is silent. `jhonstart_router`
%% is the `<lib>_<name>` shape rakun's sidecars use for the same reason.
-module(jhonstart_router).

-export([path/0, params/0, search/0, pattern/0, selected/0]).
-export([fill/5, navigate/2, last_navigation/0]).
-export([mark_dynamic/0, dynamic/0, reset_dynamic/0]).

-define(PATH, jhonstart_route_path).
-define(PARAMS, jhonstart_route_params).
-define(SEARCH, jhonstart_route_search).
-define(PATTERN, jhonstart_route_pattern).
-define(SELECTED, jhonstart_route_selected).
-define(NAV, jhonstart_route_nav).
-define(DYNAMIC, jhonstart_route_dynamic).

%% An unfilled snapshot answers the empty document rather than raising: a
%% component rendered outside a request is a legitimate thing to do (it is how
%% every test in this package renders the server pass), and `""` is already the
%% answer every accessor gives for an absent key.
get_bin(Key) ->
    case get(Key) of
        undefined -> <<"">>;
        Value -> Value
    end.

path() -> get_bin(?PATH).

params() -> get_bin(?PARAMS).

search() -> get_bin(?SEARCH).

pattern() -> get_bin(?PATTERN).

selected() ->
    case get(?SELECTED) of
        undefined -> 0;
        Value -> Value
    end.

%% Replace the whole snapshot. Every field at once, never one at a time: a
%% half-updated snapshot is a component reading the previous route's params
%% against the next route's pattern.
fill(Path, Params, Search, Pattern, Selected) ->
    put(?PATH, Path),
    put(?PARAMS, Params),
    put(?SEARCH, Search),
    put(?PATTERN, Pattern),
    put(?SELECTED, Selected),
    0.

%% The six verbs behind one cell.
%%
%% On the server `push` and `replace` RECORD a 307 redirect on the response —
%% they do not perform one, because the response is the dispatcher's to write
%% and this module is called from inside the render. `back`, `forward`,
%% `refresh` and `prefetch` are no-ops: there is no history on the server, and
%% re-requesting a payload is the browser's move.
%%
%% Recording it in the process dictionary rather than raising is what lets
%% `push("/x")` be asserted as "does not raise, and the redirect is there" in
%% the same process that rendered.
navigate(Kind, Href) ->
    put(?NAV, <<Kind/binary, " ", Href/binary>>),
    0.

last_navigation() -> get_bin(?NAV).

%% The render's DYNAMIC mark (`../router_runtime.mjs` has the same three). The
%% store is the process dictionary, so a boundary resolved in its own process
%% marks that process: front 30's `Resolved` carries the mark back and the
%% render's process ORs it into its own before the payload is written.
mark_dynamic() ->
    put(?DYNAMIC, true),
    0.

dynamic() ->
    case get(?DYNAMIC) of
        true -> true;
        _ -> false
    end.

reset_dynamic() ->
    erase(?DYNAMIC),
    0.
