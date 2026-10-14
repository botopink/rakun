%% jhonstart — the signal host half on the BEAM (front 31).
%%
%% The erlang twin of `../signal_runtime.mjs`. `capture/1` calls a boundary's
%% thunk exactly once and turns a raise into the `{error, Reason}` Result value
%% a `case` can branch on.
%%
%% A raised signal is botopink's `@panic(Reason)`, `{panic, Reason}`; a failed
%% `assert` in a component is `{bp_assert, Msg, Where}`; anything else is
%% formatted, so a crashing component is caught like one that answered `Error`.
-module(jhonstart_signal).

-export([capture/1]).

reason_of({panic, Reason}) when is_binary(Reason) -> Reason;
reason_of({panic, Reason}) when is_list(Reason) -> unicode:characters_to_binary(Reason);
reason_of({bp_assert, Msg, _Where}) when is_binary(Msg) -> Msg;
reason_of(Other) -> iolist_to_binary(io_lib:format("~p", [Other])).

%% A `@Component` lambda written as a host cell's argument takes no map: it
%% reads the map where it is written (botopink decision 374). A `@Component`
%% value handed on still takes the hidden context map first (decision 354):
%% this host passes the empty map, `undefined` (`null`).
call(Child) when is_function(Child, 1) -> Child(undefined);
call(Child) -> Child().

capture(Child) ->
    try call(Child) of
        Value -> Value
    catch
        error:E -> {error, reason_of(E)};
        throw:E -> {error, reason_of(E)};
        exit:E -> {error, reason_of(E)}
    end.
