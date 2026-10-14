%% jhonstart — `clientApp`'s cells on the BEAM (front 26 Step 6).
%%
%% There is no browser here: the cells answer the same module store
%% `../client_app.mjs` falls back to under node, in the calling process's
%% dictionary, so `test/client_app_test.bp` is one set of assertions on both
%% rows.
-module(jhonstart_client_app).

-export([location_path/0, location_search/0, mount/2, location_replace/1,
         set_location/2, mounted/1, replaced/0]).

get_or(Key, Default) ->
    case get(Key) of
        undefined -> Default;
        V -> V
    end.

location_path() -> get_or(jh_ca_path, <<"/">>).
location_search() -> get_or(jh_ca_search, <<"">>).

mount(Selector, Html) ->
    put({jh_ca_mounted, Selector}, Html),
    0.

location_replace(To) ->
    put(jh_ca_replaced, To),
    0.

set_location(Path, Search) ->
    put(jh_ca_path, Path),
    put(jh_ca_search, Search),
    put(jh_ca_replaced, <<"">>),
    [erase(K) || {{jh_ca_mounted, _} = K, _} <- get()],
    0.

mounted(Selector) -> get_or({jh_ca_mounted, Selector}, <<"">>).

replaced() -> get_or(jh_ca_replaced, <<"">>).
