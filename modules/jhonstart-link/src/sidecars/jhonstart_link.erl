%% jhonstart-link — the BEAM twin of `../link_runtime.mjs` (front 27 Step 4).
%%
%% There is no browser on the server: a link is never in flight, nothing is
%% prefetched and the route kind is unknown. `mount/0` still counts, so its
%% idempotence is one assertion on both rows.
-module(jhonstart_link).

-export([mount/0, prefetch/2, status/0, route_kind/1]).

mount() ->
    case get(jh_link_mounts) of
        undefined -> put(jh_link_mounts, 1), 1;
        N -> N
    end.

prefetch(_Href, _Mode) -> 0.
status() -> <<"">>.
route_kind(_Href) -> <<"unknown">>.
