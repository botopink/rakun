%%% rakun-security — the OAuth2 / OIDC host cells (front 79): randomness,
%%% PKCE, the single-use state store, the JWKS cache, RS256 verification, the
%%% ID-token claim checks, the token caches and the single flight a cold
%%% client-credentials source needs.
%%%
%%% Nothing here logs a code, a verifier or a token. Reasons name the claim or
%%% the check that failed, never the value that failed it.

-module(rakun_oauth2).
-export([random_url/1, s256/1, state_put/2, state_take/1, state_count/0,
         jwks_put/2, jwks_has/2, jwks_fetches/1, jwks_note_fetch/1, jwks_may_refetch/2,
         verify_rs256/2, check_claims/6, claim/2, decode_json_field/2,
         token_put/3, token_get/2, token_drop/2, flight/2, counter_bump/1, counter/1,
         reset/0, now_seconds/0,
         test_keypair/1, test_jwks/1, test_sign/2]).

-define(T, rakun_oauth2_tab).
-define(OWNER, rakun_oauth2_owner).

ensure() ->
    case ets:whereis(?T) of
        undefined ->
            Caller = self(),
            Pid = spawn(fun() ->
                                case (try erlang:register(?OWNER, self()) catch error:badarg -> false end) of
                                    true ->
                                        _ = ets:new(?T, [named_table, public, set]),
                                        Caller ! {?OWNER, ready},
                                        receive stop -> ok end;
                                    _ -> Caller ! {?OWNER, ready}
                                end
                        end),
            Ref = erlang:monitor(process, Pid),
            receive
                {?OWNER, ready} -> erlang:demonitor(Ref, [flush]), ok;
                {'DOWN', Ref, process, Pid, _} -> ok
            after 5000 -> ok
            end;
        _ -> ok
    end.

reset() ->
    ensure(),
    ets:delete_all_objects(?T),
    0.

now_seconds() -> erlang:system_time(second).

b64url(Bin) -> base64:encode(Bin, #{mode => urlsafe, padding => false}).

unb64url(Text) -> base64:decode(Text, #{mode => urlsafe, padding => false}).

%% `N` random bytes as unpadded base64url (43 characters for 32 bytes).
random_url(N) -> b64url(crypto:strong_rand_bytes(N)).

%% The S256 code challenge of a verifier.
s256(Verifier) -> b64url(crypto:hash(sha256, Verifier)).

%% ── the single-use state store ──

state_put(State, Payload) ->
    ensure(),
    ets:insert(?T, {{state, State}, Payload}),
    0.

%% The payload, removed in the same step, or `<<>>`: a replayed callback finds
%% nothing.
state_take(State) ->
    ensure(),
    case ets:take(?T, {state, State}) of
        [{_, P}] -> P;
        [] -> <<>>
    end.

state_count() ->
    ensure(),
    length([K || {{state, _} = K, _} <- ets:tab2list(?T)]).

%% ── the JWKS cache ──

%% Replaces the key set of `Issuer` with the RSA keys of a JWKS document.
jwks_put(Issuer, Json) ->
    ensure(),
    Keys = try
               #{<<"keys">> := Ks} = json:decode(Json),
               [{maps:get(<<"kid">>, K, <<>>), unb64url(maps:get(<<"n">>, K)), unb64url(maps:get(<<"e">>, K))}
                || K <- Ks, maps:get(<<"kty">>, K, <<>>) =:= <<"RSA">>]
           catch _:_ -> error
           end,
    case Keys of
        error -> 0;
        _ -> ets:insert(?T, {{jwks, Issuer}, Keys}), length(Keys)
    end.

jwks_has(Issuer, Kid) ->
    ensure(),
    case ets:lookup(?T, {jwks, Issuer}) of
        [{_, Keys}] -> lists:keymember(Kid, 1, Keys);
        [] -> false
    end.

jwks_note_fetch(Issuer) ->
    ensure(),
    ets:update_counter(?T, {jwks_fetches, Issuer}, 1, {{jwks_fetches, Issuer}, 0}),
    ets:insert(?T, {{jwks_last, Issuer}, erlang:monotonic_time(millisecond)}),
    0.

jwks_fetches(Issuer) ->
    ensure(),
    case ets:lookup(?T, {jwks_fetches, Issuer}) of [{_, N}] -> N; [] -> 0 end.

%% Whether an unknown `kid` may re-fetch now: once per `WindowMs`.
jwks_may_refetch(Issuer, WindowMs) ->
    ensure(),
    case ets:lookup(?T, {jwks_last, Issuer}) of
        [{_, At}] -> erlang:monotonic_time(millisecond) - At >= WindowMs;
        [] -> true
    end.

%% `{ok, ClaimsJson}` as `<<"ok\t", Claims/binary>>`, or `<<"error\t", Reason/binary>>`
%% — `unknown-kid`, `alg`, `malformed` or `signature`.
verify_rs256(Issuer, Token) ->
    ensure(),
    try
        [H, P, S] = binary:split(Token, <<".">>, [global]),
        Header = json:decode(unb64url(H)),
        case maps:get(<<"alg">>, Header, <<>>) of
            <<"RS256">> -> ok;
            _ -> throw(alg)
        end,
        Kid = maps:get(<<"kid">>, Header, <<>>),
        Keys = case ets:lookup(?T, {jwks, Issuer}) of [{_, Ks}] -> Ks; [] -> [] end,
        case lists:keyfind(Kid, 1, Keys) of
            false -> <<"error\tunknown-kid">>;
            {_, N, E} ->
                case crypto:verify(rsa, sha256, <<H/binary, ".", P/binary>>, unb64url(S), [E, N]) of
                    true -> <<"ok\t", (unb64url(P))/binary>>;
                    false -> <<"error\tsignature">>
                end
        end
    catch
        throw:alg -> <<"error\talg">>;
        _:_ -> <<"error\tmalformed">>
    end.

%% `<<>>` when the claims hold, else the name of the first claim that does
%% not: `iss`, `aud`, `nonce`, `exp`.
check_claims(ClaimsJson, Issuer, ClientId, Nonce, Now, Skew) ->
    try
        C = json:decode(ClaimsJson),
        IssOk = maps:get(<<"iss">>, C, <<>>) =:= Issuer,
        AudOk = case maps:get(<<"aud">>, C, <<>>) of
                    A when is_list(A) -> lists:member(ClientId, A);
                    A -> A =:= ClientId
                end,
        NonceOk = Nonce =:= <<>> orelse maps:get(<<"nonce">>, C, <<>>) =:= Nonce,
        ExpOk = case maps:get(<<"exp">>, C, undefined) of
                    Exp when is_integer(Exp) -> Exp + Skew >= Now;
                    _ -> false
                end,
        if
            not IssOk -> <<"iss">>;
            not AudOk -> <<"aud">>;
            not NonceOk -> <<"nonce">>;
            not ExpOk -> <<"exp">>;
            true -> <<>>
        end
    catch _:_ -> <<"malformed">>
    end.

%% A claim as text: a string as is, a number printed, a list of strings
%% space-joined; `<<>>` when absent.
claim(ClaimsJson, Name) ->
    try maps:get(Name, json:decode(ClaimsJson)) of
        V when is_binary(V) -> V;
        V when is_integer(V) -> integer_to_binary(V);
        V when is_list(V) -> iolist_to_binary(lists:join(<<" ">>, [X || X <- V, is_binary(X)]));
        true -> <<"true">>;
        false -> <<"false">>;
        _ -> <<>>
    catch _:_ -> <<>>
    end.

decode_json_field(Json, Name) -> claim(Json, Name).

%% ── token caches ──

token_put(Scope, Key, Value) ->
    ensure(),
    ets:insert(?T, {{token, Scope, Key}, Value}),
    0.

token_get(Scope, Key) ->
    ensure(),
    case ets:lookup(?T, {token, Scope, Key}) of [{_, V}] -> V; [] -> <<>> end.

token_drop(Scope, Key) ->
    ensure(),
    ets:delete(?T, {token, Scope, Key}),
    0.

%% One `Fun()` per key at a time: concurrent callers wait for the leader's
%% answer instead of running their own.
flight(Key, Fun) ->
    ensure(),
    FKey = {flight, Key},
    case ets:insert_new(?T, {FKey, self(), []}) of
        true ->
            V = try Fun() catch C:R:S -> finish(FKey, {raised, C, R}), erlang:raise(C, R, S) end,
            finish(FKey, {ok, V}),
            V;
        false ->
            Ref = make_ref(),
            case wait_register(FKey, Ref) of
                gone -> flight(Key, Fun);
                ok ->
                    receive
                        {Ref, {ok, V}} -> V;
                        {Ref, {raised, C, R}} -> erlang:raise(C, R, [])
                    after 30000 -> flight(Key, Fun)
                    end
            end
    end.

wait_register(FKey, Ref) ->
    case ets:lookup(?T, FKey) of
        [{_, Leader, Waiters}] ->
            case ets:select_replace(?T, [{{FKey, Leader, Waiters}, [], [{{{const, FKey}, {const, Leader}, {const, [{self(), Ref} | Waiters]}}}]}]) of
                1 -> ok;
                0 -> wait_register(FKey, Ref)
            end;
        [] -> gone
    end.

finish(FKey, Answer) ->
    case ets:take(?T, FKey) of
        [{_, _, Waiters}] -> [P ! {R, Answer} || {P, R} <- Waiters];
        [] -> ok
    end.

counter_bump(Key) ->
    ensure(),
    ets:update_counter(?T, {counter, Key}, 1, {{counter, Key}, 0}).

counter(Key) ->
    ensure(),
    case ets:lookup(?T, {counter, Key}) of [{_, N}] -> N; [] -> 0 end.

%% ── test identity provider material ──

test_keypair(Kid) ->
    {Pub, Priv} = crypto:generate_key(rsa, {2048, 65537}),
    persistent_term:put({rakun_oauth2_test_key, Kid}, {Pub, Priv}),
    0.

test_jwks(Kids) ->
    Keys = [begin
                {[E, N], _} = persistent_term:get({rakun_oauth2_test_key, K}),
                #{kty => <<"RSA">>, kid => K, alg => <<"RS256">>, use => <<"sig">>, n => b64url(N), e => b64url(E)}
            end || K <- Kids],
    iolist_to_binary(json:encode(#{keys => Keys})).

test_sign(Kid, ClaimsJson) ->
    {_, Priv} = persistent_term:get({rakun_oauth2_test_key, Kid}),
    H = b64url(iolist_to_binary(json:encode(#{alg => <<"RS256">>, typ => <<"JWT">>, kid => Kid}))),
    P = b64url(ClaimsJson),
    Sig = crypto:sign(rsa, sha256, <<H/binary, ".", P/binary>>, Priv),
    <<H/binary, ".", P/binary, ".", (b64url(Sig))/binary>>.
