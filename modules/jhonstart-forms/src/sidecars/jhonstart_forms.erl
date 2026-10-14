%% jhonstart-forms — the BEAM twin of `../form_runtime.mjs` (front 67).
%%
%% There is no browser on the server: nothing is in flight and no envelope has
%% arrived, so a hook's server pass is its quiet value. `submit/3` and
%% `invoke/3` record the call and answer the stubbed body — the same test store
%% the node half falls back to — so one set of assertions runs on both rows.
-module(jhonstart_forms).

-export([submit/3, invoke/3, pending/1, state/1, mount/1, stub/1, last_call/0]).

get_or(Key, Default) ->
    case get(Key) of
        undefined -> Default;
        V -> V
    end.

record(Id, Body, Header) ->
    put(jh_forms_last, iolist_to_binary([Id, <<"|">>, Header, <<"|">>, Body])),
    get_or(jh_forms_response, <<"">>).

submit(Id, Body, Header) -> record(Id, Body, Header).
invoke(Id, Body, Header) -> record(Id, Body, Header).
pending(_Id) -> <<"">>.
state(_Id) -> <<"">>.

mount(_Header) ->
    case get(jh_forms_mounts) of
        undefined -> put(jh_forms_mounts, 1), 1;
        N -> N
    end.

stub(Text) ->
    put(jh_forms_response, Text),
    0.

last_call() -> get_or(jh_forms_last, <<"">>).
