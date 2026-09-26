%%% rakun-security — the BEAM half of front 10.
%%%
%%% WHAT LIVES HERE AND WHY. Four things botopink cannot hold or cannot reach:
%%%
%%%   * the security CONTEXT of the request being served. A request is a
%%%     process, so the context is the process dictionary, installed for the
%%%     duration of one call (`within/2`) and restored in an `after` — a raise
%%%     inside the handler cannot leave it behind for the next request on the
%%%     same keep-alive connection, and two concurrent requests are two
%%%     processes that never see each other's;
%%%   * PBKDF2-HMAC-SHA256 (`crypto:pbkdf2_hmac/5`) and the 16-byte salt
%%%     (`crypto:strong_rand_bytes/1`). bcrypt, scrypt and Argon2 are NIFs and a
%%%     sidecar compiled at run time has no code path to load one;
%%%   * the encoder INVOCATION counter, the falsifiable form of "an unknown user
%%%     costs the same as a wrong password";
%%%   * a guard that catches ONLY the security raises (`rakun.security.*` tags)
%%%     and lets every other raise through to front 07's error entry untouched.
%%%
%%% WHAT DOES NOT LIVE HERE. The policy, the JWT checks, the Basic parse, the
%%% stored-hash format, the CSRF rule and every refusal text are botopink.
%%%
%%% MODULE ATOM. `rakun_security`, never `security`: the member emits a
%%% `security` module and `shipErlSidecars` silently skips a qualifier atom that
%%% names an emitted module.
-module(rakun_security).

-export([within/2, wire/0, note_decision/1, decision/0, slot_put/2, slot/1,
         pbkdf2/3, salt/0, encode_count/0, encode_reset/0,
         guard/2, now_seconds/0, attempt/1]).

-define(OWNER, rakun_security_owner).
-define(COUNT, rakun_security_count).
-define(CTX, rakun_security_ctx).
-define(DECISION, rakun_security_decision).

%% ═══ the context ═════════════════════════════════════════════════════════════

within(Wire, Work) ->
    Previous = erlang:get(?CTX),
    erlang:put(?CTX, Wire),
    try Work()
    after
        case Previous of
            undefined -> erlang:erase(?CTX);
            _ -> erlang:put(?CTX, Previous)
        end
    end.

wire() ->
    case erlang:get(?CTX) of
        undefined -> <<>>;
        W -> W
    end.

%% The last decision taken for this process's request — what the tests render
%% and what a log line may carry. It names a rule and a requirement, never a
%% credential.
note_decision(Line) ->
    erlang:put(?DECISION, Line),
    0.

decision() ->
    case erlang:get(?DECISION) of
        undefined -> <<>>;
        D -> D
    end.

%% A per-request slot (the request path the problem bodies name as their
%% `instance`). Process-local, like the context.
slot_put(Key, Value) ->
    erlang:put({rakun_security_slot, Key}, Value),
    0.

slot(Key) ->
    case erlang:get({rakun_security_slot, Key}) of
        undefined -> <<>>;
        V -> V
    end.

%% ═══ PBKDF2 ═════════════════════════════════════════════════════════════════

pbkdf2(Raw, SaltText, Iterations) ->
    ensure(),
    _ = ets:update_counter(?COUNT, encodes, {2, 1}, {encodes, 0}),
    Salt = base64:decode(SaltText, #{mode => urlsafe, padding => false}),
    Hash = crypto:pbkdf2_hmac(sha256, Raw, Salt, Iterations, 32),
    base64:encode(Hash, #{mode => urlsafe, padding => false}).

salt() ->
    base64:encode(crypto:strong_rand_bytes(16), #{mode => urlsafe, padding => false}).

encode_count() ->
    ensure(),
    case ets:lookup(?COUNT, encodes) of
        [{encodes, N}] -> N;
        [] -> 0
    end.

encode_reset() ->
    ensure(),
    true = ets:insert(?COUNT, {encodes, 0}),
    0.

%% ═══ the guard ══════════════════════════════════════════════════════════════
%%
%% `Work()`, with a `rakun.security.*` raise (front 07's `{rakun_problem, Tag,
%% Detail}`) turned into `OnDenied(Tag, Detail)`. Anything else is re-raised
%% with its class and stack, so the error entry and the listener see it exactly
%% as they would without this front.

guard(Work, OnDenied) ->
    try Work()
    catch
        throw:{rakun_problem, <<"rakun.security.", _/binary>> = Tag, Detail} ->
            OnDenied(Tag, Detail);
        error:{rakun_problem, <<"rakun.security.", _/binary>> = Tag, Detail} ->
            OnDenied(Tag, Detail)
    end.

%% `{ok, Work()}`, or `{error, Text}` for a raise — the text is the raise's
%% message when it is a binary (a `@panic`), its `~p` rendering otherwise.
attempt(Work) ->
    try {ok, Work()}
    catch
        _:{rakun_problem, Tag, _Detail} -> {error, Tag};
        _:Reason when is_binary(Reason) -> {error, Reason};
        _:Reason -> {error, iolist_to_binary(io_lib:format("~p", [Reason]))}
    end.

now_seconds() ->
    erlang:system_time(second).

%% ═══ the counter table ══════════════════════════════════════════════════════
%% An ETS table dies with its creator, so a dedicated owner process creates it
%% — the same shape as `rakun_chain`.

ensure() ->
    case ets:whereis(?COUNT) of
        undefined -> boot();
        _ -> ok
    end.

boot() ->
    Caller = self(),
    Pid = spawn(fun() -> owner(Caller) end),
    Ref = erlang:monitor(process, Pid),
    receive
        {?OWNER, ready} ->
            erlang:demonitor(Ref, [flush]),
            ok;
        {'DOWN', Ref, process, Pid, _} ->
            ok
    after 5000 ->
        erlang:demonitor(Ref, [flush]),
        ok
    end.

owner(Caller) ->
    case catch erlang:register(?OWNER, self()) of
        true ->
            _ = ets:new(?COUNT, [named_table, public, set]),
            Caller ! {?OWNER, ready},
            owner_loop();
        _ ->
            Caller ! {?OWNER, ready},
            ok
    end.

owner_loop() ->
    receive
        stop -> ok;
        _ -> owner_loop()
    end.
