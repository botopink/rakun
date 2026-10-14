%% jhonstart — the BEAM twin of `../island_runtime.mjs` (front 29 Step 4).
%%
%% There is no browser on the server: nothing hydrates and no island has
%% props to read. The twin exists because `client.bp` lives in the core, which
%% is compiled on both rows, and a called node-only cell reds the erlang
%% compile at its caller. Registration is kept in the calling process's
%% dictionary, keyed by the table name, so it reads back the same on both rows;
%% a starter or a loader is never called here.
-module(jhonstart_island).

-export([hydrate/2, island_props/2, register_starter/3, register_route_starters/3,
         starter_names/1, route_loaders/1]).

hydrate(_PayloadName, _TableName) -> 0.
island_props(_PayloadName, _Name) -> <<"">>.

names(Key) ->
    case get(Key) of
        undefined -> [];
        L -> L
    end.

append(Key, Name) ->
    Names = names(Key) ++ [Name],
    put(Key, Names),
    length(Names).

register_starter(TableName, Name, _Start) -> append({jh_island_starters, TableName}, Name).
register_route_starters(TableName, Pattern, _Load) -> append({jh_island_routes, TableName}, Pattern).

starter_names(TableName) -> names({jh_island_starters, TableName}).
route_loaders(TableName) -> names({jh_island_routes, TableName}).
