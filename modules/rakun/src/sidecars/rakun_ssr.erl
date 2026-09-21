%%% rakun — the SSR pipeline's BEAM half: the erlang twin of `src/ssr.mjs`.
%%%
%%% WHAT LIVES HERE AND WHY. botopink has no top-level mutable state, and three
%%% of the things this front holds are not values a string table can hold: the
%%% installed `RenderHooks` (a record of seven FUNCTIONS — decision 77), the
%%% gather over unstarted THUNKS, and two per-render ordinals. That is front
%%% 22's test — "is the thing being stored pure?" — and a closure is not.
%%%
%%% WHAT DOES NOT LIVE HERE. The escaping, the walker, the composition order,
%%% the payload format, the document shell and the chunk protocol are botopink
%%% in `ssr.bp`, compiled to both targets. This module never sees HTML.
%%%
%%% MODULE ATOM. `src/sidecars/rakun_ssr.erl`, never `src/ssr.erl`:
%%% `shipErlSidecars` skips a qualifier atom matching a module the build
%%% emitted, rakun emits `rakun/ssr`, and the skip is SILENT. Every rakun
%%% sidecar is `rakun_<name>.erl`.
%%%
%%% PROCESS-LOCAL, DELIBERATELY. rakun serves each request in its own BEAM
%%% process, which is where emilia's sheet already lives, so the hooks, the
%%% depth and the navigation counter are the serving process's dictionary and
%%% not an ETS area: two requests in flight must not see one another's hooks.
%%% `all/1`'s children are spawned FROM that process and answer back to it.
-module(rakun_ssr).

-export([set_hooks/1, has_hooks/0, hooks_or/1,
         set_selected/1, selected_depth/0, next_nav/0,
         all/1, settled_order/0, concurrent/0, reset/0]).

-define(HOOKS, rakun_ssr_hooks).
-define(SELECTED, rakun_ssr_selected).
-define(NAV, rakun_ssr_nav).
-define(ORDER, rakun_ssr_order).

%% ═══ the installed hooks ═════════════════════════════════════════════════════

set_hooks(H) ->
    _ = erlang:put(?HOOKS, H),
    0.

has_hooks() ->
    erlang:get(?HOOKS) =/= undefined.

hooks_or(Fallback) ->
    case erlang:get(?HOOKS) of
        undefined -> Fallback;
        H -> H
    end.

%% ═══ the two per-render ordinals ═════════════════════════════════════════════
%%
%% `selected` is the layout depth. It is a slot rather than a field of
%% `LayoutProps` because that record is front 22's and carries three fields;
%% widening it would touch a file this front does not own, and a fourth
%% positional argument is not expressible while a declared parameter default is
%% never applied.

set_selected(Depth) ->
    _ = erlang:put(?SELECTED, Depth),
    Depth.

selected_depth() ->
    case erlang:get(?SELECTED) of
        undefined -> 0;
        D -> D
    end.

next_nav() ->
    N = case erlang:get(?NAV) of
            undefined -> 0;
            V -> V
        end + 1,
    _ = erlang:put(?NAV, N),
    N.

%% ═══ the gather over unstarted thunks ════════════════════════════════════════
%%
%% `@Future<T>` lowers EAGERLY on this row — `libs/std/src/http.bp` says so in
%% as many words — so a future is a value that has already been computed and
%% awaiting two of them runs them one after the other at full latency. The
%% concurrency therefore comes from PROCESSES: one `spawn_monitor` per thunk,
%% the results gathered by INDEX, and the order they settled in recorded on the
%% side, because a gather by index cannot also answer it.
%%
%% A child that dies without answering takes the gather down with it, naming the
%% index: a render that silently drops one of its sections is worse than one
%% that fails.

all(Thunks) ->
    Fs = lists:reverse(lists:foldl(fun(F, Acc) -> [F | Acc] end, [], Thunks)),
    N = length(Fs),
    Self = self(),
    Children =
        [begin
             {Pid, Ref} =
                 spawn_monitor(fun() -> Self ! {rakun_ssr_done, I, F()} end),
             {I, Pid, Ref}
         end
         || {I, F} <- lists:zip(lists:seq(0, N - 1), Fs)],
    {Values, Order} = gather(Children, #{}, []),
    _ = erlang:put(?ORDER, join_ints(lists:reverse(Order))),
    [maps:get(I, Values) || I <- lists:seq(0, N - 1)].

gather([], Values, Order) ->
    {Values, Order};
gather(Children, Values, Order) ->
    receive
        {rakun_ssr_done, I, V} ->
            {value, {I, _Pid, Ref}, Rest} =
                lists:keytake(I, 1, Children),
            erlang:demonitor(Ref, [flush]),
            gather(Rest, maps:put(I, V, Values), [I | Order]);
        {'DOWN', Ref, process, _Pid, Reason} ->
            case lists:keyfind(Ref, 3, Children) of
                {I, _P, Ref} ->
                    erlang:error({rakun_ssr_thunk_died, I, Reason});
                false ->
                    gather(Children, Values, Order)
            end
    end.

join_ints([]) -> <<>>;
join_ints([H | T]) ->
    lists:foldl(fun(X, Acc) ->
                        <<Acc/binary, ",", (integer_to_binary(X))/binary>>
                end,
                integer_to_binary(H), T).

settled_order() ->
    case erlang:get(?ORDER) of
        undefined -> <<>>;
        O -> O
    end.

%% This row spawns. The node row cannot, and says so; the one timing assertion
%% in `test/ssr_test.bp` reads this cell rather than claiming the same shape on
%% both rows.
concurrent() -> true.

reset() ->
    _ = erlang:erase(?HOOKS),
    _ = erlang:erase(?SELECTED),
    _ = erlang:erase(?NAV),
    _ = erlang:erase(?ORDER),
    0.
