%%% rakun — navigation signals, BEAM half (front 63).
%%%
%%% A signal is a host-level THROW of a string reason beginning `nav:` (the
%%% bundled library `routing`'s `signalReason`), not a returned sentinel: it
%%% composes through nested calls and through `await` (an eager `@Task` on the
%%% BEAM), and botopink's `try … catch` — which unwraps a `@Result` and nothing
%%% else — cannot swallow it. This module throws and catches; which reasons are
%%% signals is `routing`'s `isSignalReason`, decided in `navigation.bp`.
%%%
%%% MODULE ATOM. `rakun_navigation`, never `navigation`: `shipErlSidecars` skips
%%% an atom matching an emitted module basename, silently.
-module(rakun_navigation).

-export([signal/1, try_body/1, value/1, rethrow/1]).

-define(VALUE, rakun_navigation_value).

signal(Reason) ->
    erlang:throw(Reason).

%% Run `Body`. `<<>>` when it returned (its value is kept for `value/1`); the
%% reason when it THREW a string (the botopink side decides whether that is a
%% signal); anything else — an error, an exit, a non-string throw — is re-raised
%% unchanged, with its original reason and stack.
try_body(Body) ->
    try Body() of
        V -> put(?VALUE, {ok, V}), <<>>
    catch
        throw:Reason when is_binary(Reason) -> erase(?VALUE), Reason;
        error:{bp_host, Text} = Err:Stack ->
            case unmark(Text) of
                {ok, Reason} when is_binary(Reason) -> erase(?VALUE), Reason;
                _ -> erlang:raise(error, Err, Stack)
            end;
        Class:Reason:Stack -> erlang:raise(Class, Reason, Stack)
    end.

value(Fallback) ->
    case erase(?VALUE) of
        {ok, V} -> V;
        _ -> Fallback
    end.

rethrow(Reason) ->
    erlang:throw(Reason).

%% Decision 546: a library binding without `result: true` has its calls wrapped, so a
%% `throw(Term)` raised inside one reaches its caller as `error:{bp_host, Text}`, `Text`
%% the term by `~tp` without the stack (compiler-core `erl_template.host_mark_tail`;
%% decisions 527 (4), 546). `unmark/1` reads the term back from that text.
unmark(Text) when is_binary(Text) ->
    try
        {ok, Toks, _} = erl_scan:string(unicode:characters_to_list(Text) ++ "."),
        {ok, Term} = erl_parse:parse_term(Toks),
        {ok, Term}
    catch _:_ -> error
    end;
unmark(_) -> error.
