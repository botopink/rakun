%%% rakun-app — server actions, the BEAM half of front 24.
%%%
%%% WHAT LIVES HERE AND WHY. Only what botopink cannot hold or reach:
%%%
%%%   * the ACTION registry: `{Module, Name} -> Run`, where `Module` is read off
%%%     the function value itself (`erlang:fun_info/2`) — the module the
%%%     `#[serverAction]` fn was declared in, which `@Decl` does not carry;
%%%   * the CALL: an action returns an `ActionResult`, an `Ok(ActionResult)` or
%%%     an `Error(E)` (its `@Task` is eager on the BEAM), or raises. `call/2`
%%%     classifies that into a word and keeps the value for `result/0` /
%%%     `failure/0`; a navigation signal (a thrown `nav:` binary, front 63) is
%%%     re-thrown untouched so the caller's `captureSignals` sees it;
%%%   * the BODY HOOK front 04's connection process asks before reading a
%%%     body (`rakun_body_hook`), and the count of bodies it admitted.
%%%
%%% WHAT DOES NOT LIVE HERE. The id derivation, the constant-time compare, the
%%% CSRF rule, the limits, the envelope and every refusal text are botopink.
%%%
%%% MODULE ATOM. `rakun_actions`, never `actions`: the bundled library
%%% `actions` emits modules of that name.
-module(rakun_actions).

-export([register/2, registered/0, run_of/2, call/2, result/0, failure/0,
         install_body_hook/1, uninstall_body_hook/0, admitted/0, count_admitted/0, reset/0]).

-define(TABLE, rakun_actions_registry).

register(Name, Run) ->
    ensure(),
    {module, Module} = erlang:fun_info(Run, module),
    true = ets:insert(?TABLE, {{atom_to_binary(Module), Name}, Run}),
    0.

%% `module|name`, sorted.
registered() ->
    ensure(),
    lists:sort([<<M/binary, "|", N/binary>> || {{M, N}, _} <- ets:tab2list(?TABLE)]).

run_of(Module, Name) ->
    ensure(),
    case ets:lookup(?TABLE, {Module, Name}) of
        [{_, Run}] -> Run;
        [] -> erlang:error({rakun_actions, <<"no such action">>})
    end.

call(Run, Form) ->
    erase(rakun_actions_result),
    erase(rakun_actions_failure),
    try Run(Form) of
        {ok, R} when is_tuple(R) -> put(rakun_actions_result, R), <<"ok">>;
        {error, E} -> put(rakun_actions_failure, text(E)), <<"failed">>;
        R when is_tuple(R), tuple_size(R) >= 1, is_atom(element(1, R)) -> put(rakun_actions_result, R), <<"ok">>;
        Other -> put(rakun_actions_failure, iolist_to_binary(io_lib:format("the action returned ~0p, not an ActionResult", [Other]))), <<"failed">>
    catch
        throw:<<"nav:", _/binary>> = Signal -> erlang:throw(Signal);
        error:{panic, Msg} -> put(rakun_actions_failure, text(Msg)), <<"failed">>;
        _:Reason -> put(rakun_actions_failure, text(Reason)), <<"failed">>
    end.

result() -> get(rakun_actions_result).
failure() ->
    case get(rakun_actions_failure) of
        undefined -> <<>>;
        F -> F
    end.

text(B) when is_binary(B) -> B;
text({panic, B}) when is_binary(B) -> B;
text(Other) -> iolist_to_binary(io_lib:format("~0p", [Other])).

%% ═══ the body hook ═══════════════════════════════════════════════════════════

install_body_hook(Hook) ->
    ensure(),
    persistent_term:put(rakun_body_hook, fun(Verb, Path, HeadersJson) ->
        case Hook(Verb, Path, HeadersJson) of
            <<>> -> bump(admitted), <<>>;
            Refusal -> Refusal
        end
    end),
    0.

uninstall_body_hook() ->
    _ = persistent_term:erase(rakun_body_hook),
    0.

admitted() -> count_admitted().

count_admitted() ->
    ensure(),
    case ets:lookup(?TABLE, {counter, admitted}) of
        [{_, N}] -> N;
        [] -> 0
    end.

bump(Key) ->
    ets:update_counter(?TABLE, {counter, Key}, {2, 1}, {{counter, Key}, 0}).

reset() ->
    ensure(),
    true = ets:delete_all_objects(?TABLE),
    uninstall_body_hook().

ensure() ->
    case ets:whereis(?TABLE) of
        undefined ->
            Caller = self(),
            Pid = spawn(fun() ->
                                case catch erlang:register(rakun_actions_owner, self()) of
                                    true ->
                                        _ = ets:new(?TABLE, [named_table, public, set]),
                                        Caller ! {rakun_actions_owner, ready},
                                        receive stop -> ok end;
                                    _ -> Caller ! {rakun_actions_owner, ready}
                                end
                        end),
            Ref = erlang:monitor(process, Pid),
            receive
                {rakun_actions_owner, ready} -> erlang:demonitor(Ref, [flush]), ok;
                {'DOWN', Ref, process, Pid, _} -> ok
            after 5000 -> erlang:demonitor(Ref, [flush]), ok
            end;
        _ -> ok
    end.
