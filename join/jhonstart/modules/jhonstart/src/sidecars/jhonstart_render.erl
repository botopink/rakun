%% jhonstart — the render's host half on the BEAM (front 30).
%%
%% The erlang twin of `../render.mjs`'s per-render state, cell for cell. A
%% render is a process, so the state is the CALLING PROCESS's dictionary: two
%% concurrent renders cannot see each other's boundaries, islands or writes.
%% The hooks `setHooks` stores are the exception — onze sets them once at boot,
%% in another process — so they live in `persistent_term`.
%%
%% `each_completed/2` is the completion-order gather: one spawned process per
%% thunk, gathered with a reference unique to the call, each value handed to
%% `OnDone(Index, Value)` IN THE CALLING PROCESS as it arrives, so every write
%% happens where the `Response` was built. A crash in a thunk is re-raised.
%%
%% The three browser cells answer the empty value: there is no DOM here.
-module(jhonstart_render).

-export([state_reset/0, push_boundary/1, take_boundaries/0, push_node/1, node_at/1,
         next_island_ordinal/0, push_island/1, islands/0, set_island_base/1,
         stash_not_found/1, stashed_not_found/1, has_stash/0,
         mark_write/0, writes/0, next_nav/0, set_hooks/1, hooks/1,
         each_completed/2, next_hole_ordinal/0, set_late/1, late/0, collect_resolved/1, take_resolved/0,
         payload_text/1, register_fill/2, register_signal/2,
         styled_sheet/1, set_styled_sheet/1]).

-define(B, jhonstart_render_boundaries).
-define(I, jhonstart_render_islands).
-define(IB, jhonstart_render_island_base).
-define(S, jhonstart_render_stash).
-define(W, jhonstart_render_writes).
-define(HOOKS, jhonstart_render_hooks).
-define(NAV, jhonstart_render_nav).
-define(H, jhonstart_render_holes).
-define(L, jhonstart_render_late).
-define(R, jhonstart_render_resolved).
-define(SS, jhonstart_render_styled_sheet).
-define(N, jhonstart_render_nodes).

get_or(Key, Default) ->
    case get(Key) of
        undefined -> Default;
        V -> V
    end.

state_reset() ->
    put(?B, []), put(?N, []), put(?I, []), put(?IB, 0), erase(?S), put(?W, 0), put(?H, 0), erase(?L), erase(?SS),
    0.

%% The render's `styled` sheet (front 119): what the components computed at
%% render registered through `StyledContext`, a `styled` `Sheet` value kept
%% opaquely — `styled_root.bp` adds to it, the sink reads it.
styled_sheet(Fallback) -> get_or(?SS, Fallback).

set_styled_sheet(S) ->
    put(?SS, S),
    0.

push_boundary(B) ->
    L = get_or(?B, []) ++ [B],
    put(?B, L),
    length(L).

%% The boundary nodes a composition placed in its tree (decision 414): an
%% error or a not-found boundary, its placeholder carrying the index.
push_node(N) ->
    L = get_or(?N, []) ++ [N],
    put(?N, L),
    length(L) - 1.

node_at(Index) ->
    lists:nth(binary_to_integer(Index) + 1, get_or(?N, [])).

take_boundaries() ->
    L = get_or(?B, []),
    put(?B, []),
    L.

next_island_ordinal() ->
    get_or(?IB, 0) + length(get_or(?I, [])).

push_island(Row) ->
    L = get_or(?I, []) ++ [Row],
    put(?I, L),
    length(L).

islands() -> get_or(?I, []).

set_island_base(N) ->
    put(?IB, N), put(?I, []),
    0.

stash_not_found(E) ->
    case get(?S) of
        undefined -> put(?S, E);
        _ -> ok
    end,
    0.

stashed_not_found(Fallback) -> get_or(?S, Fallback).

has_stash() -> get(?S) =/= undefined.

mark_write() ->
    N = get_or(?W, 0) + 1,
    put(?W, N),
    N.

writes() -> get_or(?W, 0).

set_late(State) ->
    case get(?L) of
        undefined -> put(?L, State);
        _ -> ok
    end,
    0.

late() -> get_or(?L, <<"">>).

collect_resolved(R) ->
    L = get_or(?R, []) ++ [R],
    put(?R, L),
    length(L).

take_resolved() ->
    L = get_or(?R, []),
    put(?R, []),
    L.

next_hole_ordinal() ->
    N = get_or(?H, 0) + 1,
    put(?H, N),
    N.

next_nav() ->
    erlang:unique_integer([positive, monotonic]).

set_hooks(H) ->
    persistent_term:put(?HOOKS, H),
    ok.

hooks(Fallback) -> persistent_term:get(?HOOKS, Fallback).

each_completed(Tasks, OnDone) ->
    Me = self(),
    Ref = erlang:make_ref(),
    N = length(Tasks),
    lists:foreach(
      fun(I) ->
          Task = lists:nth(I, Tasks),
          erlang:spawn(fun() ->
              Me ! {Ref, I, try {ok, Task()} catch C:E:St -> {crash, C, E, St} end}
          end)
      end, lists:seq(1, N)),
    gather(N, Ref, OnDone).

gather(0, _Ref, _OnDone) -> 0;
gather(N, Ref, OnDone) ->
    receive
        {Ref, I, {ok, V}} ->
            OnDone(I - 1, V),
            gather(N - 1, Ref, OnDone);
        {Ref, _I, {crash, C, E, St}} ->
            erlang:raise(C, E, St)
    end.

payload_text(_Name) -> <<"">>.
register_fill(_Name, _Holes) -> 0.
register_signal(_Name, _Allowed) -> 0.
