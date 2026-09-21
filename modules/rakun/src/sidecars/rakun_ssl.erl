%%% rakun — the SSL bundle registry, BEAM half: the erlang twin of
%%% `src/ssl_bundle.mjs`.
%%%
%%% WHAT LIVES HERE AND WHY. botopink has no top-level mutable state, so the
%%% registry — a two-level `name` -> `field` -> value table, in registration
%%% order — lives in the host. Beside it are the two pieces of X.509 reading that
%%% are not string work (`public_key:pkix_decode_cert/2` for the certificate's
%%% fields, and a public-key comparison for the certificate/key correspondence
%%% check), and the ONE function that is genuinely erlang-only: turning the
%%% encoded option blob into a real `ssl:listen/2` option list.
%%%
%%% WHAT DOES *NOT* LIVE HERE. The property grammar, the defaults, the posture
%%% mapping, the option-list ENCODING, the JKS refusal, the reload rule and every
%%% refusal message are botopink, in `src/ssl_bundle.bp`, compiled to both
%%% targets. This module holds tables, a decoder and a certificate reader. It
%%% never reads a property and never decides what a bundle is — which is what
%%% makes "the two rows cannot disagree about what a bundle resolved to" a
%%% property rather than a hope.
%%%
%%% WHY THIS IS PLUMBING AND NOT CRYPTOGRAPHY. OTP ships `ssl` and `public_key`
%%% in the standard distribution: TLS 1.2 and 1.3, SNI, ALPN, session reuse and
%%% peer verification are already there, and so is certificate decoding. This
%%% front writes no protocol code. It is also why the front is safe where front
%%% 04's cowboy decision was not: `ssl` is part of OTP, so
%%% `application:ensure_all_started(ssl)` cannot fail for the reason
%%% `cowboy:start_clear/3` would.
%%%
%%% MODULE ATOM. `src/sidecars/rakun_ssl.erl`, never `ssl.erl` (it would shadow
%%% OTP's own module) and never `ssl_bundle.erl` (`shipErlSidecars` skips any
%%% qualifier atom matching a module the build emitted, and rakun emits
%%% `rakun/ssl_bundle` — basename `ssl_bundle` — so the skip would be SILENT and
%%% the program would die with `undefined function ssl_bundle:put/3`).
%%%
%%% TABLE OWNERSHIP. An ETS table dies with the process that created it, and a
%%% registration runs in whatever process loaded the module. So the tables are
%%% created by a dedicated owner process that does nothing but stay alive,
%%% registered under a name so a second caller losing the race finds the tables
%%% already there rather than making a second set. This is `rakun_chain`'s shape
%%% and `rakun_file_router`'s before it, and it is here for the same reason.
-module(rakun_ssl).

%% the registry cells of `src/ssl_bundle.bp`
-export([put/3, get/2, names/0, forget/1, reset/0]).
%% the X.509 reader
-export([cert_info/1, key_matches/2]).
%% the five consumer seams
-export([listener_opts/1, client_opts/2, expiry_days/1, subject/1,
         last_error/1]).
%% erlang-only: what front 04's acceptor and a client-side caller actually pass
%% to OTP. No `.bp` cell names these; see § THE TRANSPORT SEAM below.
-export([listen_options/1, connect_options/2, transport/1, handshake_timeout/1,
         decode_blob/1]).

%% reachable for a test or a later front
-export([ensure/0, owner/1]).

-define(VALS,  rakun_ssl_vals).    %% set:         {{Name, Field}, Value}
-define(ORDER, rakun_ssl_order).   %% ordered_set: {Seq, Name}
-define(SEQ,   rakun_ssl_seq).     %% set:         {Name, Seq} | {counter, N}
-define(OWNER, rakun_ssl_owner).

%% ═══ lifecycle ═══════════════════════════════════════════════════════════════

ensure() ->
    case ets:whereis(?VALS) of
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
    Won = try erlang:register(?OWNER, self()) catch _:_ -> false end,
    case Won of
        true ->
            Common = [named_table, public, {read_concurrency, true}],
            _ = ets:new(?VALS, [set | Common]),
            _ = ets:new(?ORDER, [ordered_set | Common]),
            _ = ets:new(?SEQ, [set | Common]),
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

%% ═══ the registry ════════════════════════════════════════════════════════════

put(Name, Field, Value) ->
    ensure(),
    _ = remember(Name),
    true = ets:insert(?VALS, {{bin(Name), bin(Field)}, bin(Value)}),
    0.

get(Name, Field) ->
    ensure(),
    case ets:lookup(?VALS, {bin(Name), bin(Field)}) of
        [{_, V}] -> V;
        [] -> <<>>
    end.

%% Registration order, not sorted: a bundle's place in the list is the place its
%% name has in the property list, which is what `sslBundleNames()` promises.
names() ->
    ensure(),
    join(<<"\n">>, [N || {_Seq, N} <- ets:tab2list(?ORDER)]).

forget(Name) ->
    ensure(),
    B = bin(Name),
    case ets:lookup(?SEQ, B) of
        [{_, Seq}] ->
            true = ets:delete(?ORDER, Seq),
            true = ets:delete(?SEQ, B);
        [] -> ok
    end,
    true = ets:match_delete(?VALS, {{B, '_'}, '_'}),
    0.

reset() ->
    ensure(),
    true = ets:delete_all_objects(?VALS),
    true = ets:delete_all_objects(?ORDER),
    true = ets:delete_all_objects(?SEQ),
    0.

remember(Name) ->
    B = bin(Name),
    case ets:lookup(?SEQ, B) of
        [{_, _}] -> ok;
        [] ->
            Seq = ets:update_counter(?SEQ, counter, {2, 1}, {counter, 0}),
            true = ets:insert(?SEQ, {B, Seq}),
            true = ets:insert(?ORDER, {Seq, B}),
            ok
    end.

%% ═══ the five consumer seams ═════════════════════════════════════════════════

listener_opts(Bundle) -> get(Bundle, <<"listener">>).

%% SNI is the caller's hostname and the bundle is not, so it is appended here
%% rather than stored. `verify_hostname` already said whether it is checked.
client_opts(Bundle, Host) ->
    case get(Bundle, <<"client">>) of
        <<>> -> <<>>;
        Base -> <<Base/binary, ";server_name_indication|", (bin(Host))/binary>>
    end.

expiry_days(Bundle) -> to_int(get(Bundle, <<"days">>)).

subject(Bundle) -> get(Bundle, <<"subject">>).

last_error(Bundle) -> get(Bundle, <<"error">>).

%% ═══ the X.509 reader ════════════════════════════════════════════════════════
%%
%% THE RENDERING CONTRACT. `subject` and `issuer` are canonicalised to
%% `CN=...,O=...` in certificate order, because node answers newline-separated
%% attributes and OTP answers an `rdnSequence` of OID tuples, and one assertion
%% has to be able to name one string. The instants are `YYYY-MM-DDTHH:MM:SSZ`.
%% `daysRemaining` is FLOORED, so a certificate with twelve hours left reads `0`
%% and one that expired an hour ago reads `-1`.

cert_info(Pem) ->
    try
        case [D || {'Certificate', D, not_encrypted} <- public_key:pem_decode(bin(Pem))] of
            [] ->
                <<"error|no PEM CERTIFICATE block">>;
            [Der | _] ->
                OTPCert = public_key:pkix_decode_cert(Der, otp),
                TBS = element(2, OTPCert),
                Issuer = element(5, TBS),
                {'Validity', NotBefore, NotAfter} = element(6, TBS),
                Subject = element(7, TBS),
                join(<<";">>, [
                    <<"subject|", (rdn(Subject))/binary>>,
                    <<"issuer|", (rdn(Issuer))/binary>>,
                    <<"notBefore|", (iso(NotBefore))/binary>>,
                    <<"notAfter|", (iso(NotAfter))/binary>>,
                    <<"daysRemaining|", (integer_to_binary(days_until(NotAfter)))/binary>>
                ])
        end
    catch _:Reason ->
        <<"error|", (scrub(iolist_to_binary(io_lib:format("~p", [Reason]))))/binary>>
    end.

%% A certificate with no key is not a mismatch — a verify-only bundle has none,
%% and `ssl_bundle.bp` never calls this for one. An unreadable or unsupported key
%% IS answered `false`: rakun will not present material it could not load, and a
%% refusal naming the bundle is a better outcome than a first-handshake failure
%% naming the peer.
key_matches(<<>>, _) -> false;
key_matches(_, <<>>) -> false;
key_matches(CertPem, KeyPem) ->
    try
        [Der | _] = [D || {'Certificate', D, not_encrypted} <- public_key:pem_decode(bin(CertPem))],
        OTPCert = public_key:pkix_decode_cert(Der, otp),
        TBS = element(2, OTPCert),
        SPKI = element(8, TBS),
        CertPub = element(3, SPKI),
        [Entry | _] = [E || E <- public_key:pem_decode(bin(KeyPem)),
                            element(1, E) =/= 'Certificate'],
        KeyPub = public_of(public_key:pem_entry_decode(Entry)),
        KeyPub =/= unsupported andalso same_key(CertPub, KeyPub)
    catch _:_ ->
        false
    end.

public_of(Key) when element(1, Key) =:= 'RSAPrivateKey' ->
    {rsa, element(3, Key), element(4, Key)};
public_of(Key) when element(1, Key) =:= 'ECPrivateKey' ->
    case element(5, Key) of
        asn1_NOVALUE -> unsupported;
        Point -> {ec, Point}
    end;
public_of(_) ->
    unsupported.

same_key({rsa, N, E}, _) when N =:= undefined; E =:= undefined -> false;
same_key(CertPub, {rsa, N, E}) when element(1, CertPub) =:= 'RSAPublicKey' ->
    element(2, CertPub) =:= N andalso element(3, CertPub) =:= E;
same_key({CertPoint, _Params}, {ec, Point}) when element(1, CertPoint) =:= 'ECPoint' ->
    element(2, CertPoint) =:= Point;
same_key(_, _) ->
    false.

%% ── RDN canonicalisation ─────────────────────────────────────────────────────

rdn({rdnSequence, Seq}) ->
    join(<<",">>, lists:flatmap(fun(Set) -> [attr(A) || A <- Set] end, Seq));
rdn(_) ->
    <<>>.

attr({'AttributeTypeAndValue', Oid, Value}) ->
    <<(oid_name(Oid))/binary, "=", (attr_value(Value))/binary>>;
attr(_) ->
    <<>>.

oid_name({2, 5, 4, 3})  -> <<"CN">>;
oid_name({2, 5, 4, 6})  -> <<"C">>;
oid_name({2, 5, 4, 7})  -> <<"L">>;
oid_name({2, 5, 4, 8})  -> <<"ST">>;
oid_name({2, 5, 4, 10}) -> <<"O">>;
oid_name({2, 5, 4, 11}) -> <<"OU">>;
oid_name({1, 2, 840, 113549, 1, 9, 1}) -> <<"emailAddress">>;
oid_name(Oid) -> iolist_to_binary(io_lib:format("~p", [Oid])).

attr_value({_Kind, V}) -> scrub(bin(V));
attr_value(V) -> scrub(bin(V)).

%% ── instants ─────────────────────────────────────────────────────────────────

iso(Time) ->
    case datetime(Time) of
        undefined -> <<>>;
        {{Y, M, D}, {H, Mi, S}} ->
            iolist_to_binary(
              io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0wZ",
                            [Y, M, D, H, Mi, S]))
    end.

days_until(Time) ->
    case datetime(Time) of
        undefined -> 0;
        DT ->
            Then = calendar:datetime_to_gregorian_seconds(DT),
            Now = calendar:datetime_to_gregorian_seconds(calendar:universal_time()),
            floor((Then - Now) / 86400)
    end.

%% A UTCTime carries a two-digit year (RFC 5280: 50 and above is 19xx); a
%% GeneralizedTime carries four. Both end in `Z` and rakun stores UTC only.
datetime({utcTime, S}) ->
    case string_of(S) of
        [A, B | Rest] ->
            YY = list_to_integer([A, B]),
            Y = case YY >= 50 of true -> 1900 + YY; false -> 2000 + YY end,
            parts(Y, Rest);
        _ -> undefined
    end;
datetime({generalTime, S}) ->
    case string_of(S) of
        [A, B, C, D | Rest] -> parts(list_to_integer([A, B, C, D]), Rest);
        _ -> undefined
    end;
datetime(_) ->
    undefined.

parts(Y, [M1, M2, D1, D2, H1, H2, Mi1, Mi2, S1, S2 | _]) ->
    {{Y, list_to_integer([M1, M2]), list_to_integer([D1, D2])},
     {list_to_integer([H1, H2]), list_to_integer([Mi1, Mi2]),
      list_to_integer([S1, S2])}};
parts(Y, [M1, M2, D1, D2, H1, H2, Mi1, Mi2 | _]) ->
    {{Y, list_to_integer([M1, M2]), list_to_integer([D1, D2])},
     {list_to_integer([H1, H2]), list_to_integer([Mi1, Mi2]), 0}};
parts(_, _) ->
    undefined.

string_of(S) when is_binary(S) -> binary_to_list(S);
string_of(S) when is_list(S) -> S.

%% ═══ THE TRANSPORT SEAM ══════════════════════════════════════════════════════
%%
%% OTP's `ssl` exposes the same five functions with the same shapes as `gen_tcp`
%% — `listen/2`, `transport_accept/1` + `handshake/2`, `send/2`, `recv/3`,
%% `close/1` — so front 04's acceptor takes the transport MODULE as a variable
%% rather than branching on it, the way `ranch_tcp` and `ranch_ssl` are
%% interchangeable. `transport/1` answers the module and `listen_options/1` the
%% option list; the acceptor loop is otherwise unchanged.
%%
%% THE ONE ASYMMETRY. `ssl:handshake/2` must run in the process that will OWN the
%% socket, not in the acceptor, or a slow or hostile client blocks every other
%% connection from being accepted. So the connection process performs the
%% handshake as its first act, bounded by `handshake_timeout/1`
%% (`rakun.ssl.handshake-timeout`, default 5000 ms). That is a real
%% denial-of-service difference and it is why the seam is a step rather than a
%% line.
%%
%% NOTHING IN `modules/rakun/src/sidecars/rakun_runtime.erl` CALLS THIS YET. The
%% acceptor is front 04's file and this front does not own it; these three
%% functions are the shape it takes when it does. They are covered by reading,
%% not by a `.bp` cell, for the same reason front 07 recorded about `run/6`.

transport(Bundle) ->
    case get(Bundle, <<"transport">>) of
        <<"ssl">> -> ssl;
        _ -> gen_tcp
    end.

handshake_timeout(Bundle) ->
    case to_int(blob_get(listener_opts(Bundle), <<"handshake_timeout">>)) of
        0 -> 5000;
        N -> N
    end.

listen_options(Bundle) ->
    material(listener_opts(Bundle)) ++ verification(listener_opts(Bundle), listener).

connect_options(Bundle, Host) ->
    Blob = client_opts(Bundle, Host),
    material(Blob) ++ verification(Blob, client)
        ++ [{server_name_indication, binary_to_list(blob_get(Blob, <<"server_name_indication">>))}].

material(Blob) ->
    lists:flatten([
        opt_file(certfile, blob_get(Blob, <<"certfile">>)),
        opt_file(keyfile, blob_get(Blob, <<"keyfile">>)),
        opt_file(cacertfile, blob_get(Blob, <<"cacertfile">>)),
        opt_pass(blob_get(Blob, <<"password">>)),
        opt_versions(blob_get(Blob, <<"versions">>)),
        opt_ciphers(blob_get(Blob, <<"ciphers">>))
    ]).

verification(Blob, listener) ->
    Verify = case blob_get(Blob, <<"verify">>) of
                 <<"verify_peer">> -> verify_peer;
                 _ -> verify_none
             end,
    Fail = blob_get(Blob, <<"fail_if_no_peer_cert">>) =:= <<"true">>,
    [{verify, Verify}, {fail_if_no_peer_cert, Fail}];
verification(Blob, client) ->
    case blob_get(Blob, <<"verify">>) of
        <<"verify_peer">> ->
            case blob_get(Blob, <<"verify_hostname">>) of
                <<"true">> ->
                    %% `verify=full` is the chain AND the hostname. The SNI value
                    %% is appended by `connect_options/2`, which is where the
                    %% caller's hostname enters; it is not repeated here.
                    [{verify, verify_peer},
                     {customize_hostname_check,
                      [{match_fun, public_key:pkix_verify_hostname_match_fun(https)}]}];
                _ ->
                    [{verify, verify_peer}]
            end;
        _ ->
            [{verify, verify_none}]
    end.

opt_file(_Key, <<>>) -> [];
opt_file(Key, Path) -> [{Key, binary_to_list(Path)}].

opt_pass(<<>>) -> [];
opt_pass(P) -> [{password, binary_to_list(P)}].

opt_versions(<<>>) -> [];
opt_versions(Raw) ->
    [{versions, [version_atom(V) || V <- binary:split(Raw, <<",">>, [global]), V =/= <<>>]}].

version_atom(<<"tlsv1.3">>) -> 'tlsv1.3';
version_atom(<<"tlsv1.2">>) -> 'tlsv1.2';
version_atom(Other) -> binary_to_atom(Other, utf8).

opt_ciphers(<<>>) -> [];
opt_ciphers(Raw) ->
    [{ciphers, [binary_to_list(C) || C <- binary:split(Raw, <<":">>, [global]), C =/= <<>>]}].

%% ═══ the blob ════════════════════════════════════════════════════════════════
%%
%% `key|value` per record, `;` between records — the same line-oriented encoding
%% the rest of the milestone uses. A consumer never parses it; it passes it back.

decode_blob(Blob) ->
    [begin
         case binary:split(R, <<"|">>) of
             [K, V] -> {K, V};
             [K] -> {K, <<>>}
         end
     end || R <- binary:split(bin(Blob), <<";">>, [global]), R =/= <<>>].

blob_get(Blob, Key) ->
    case lists:keyfind(Key, 1, decode_blob(Blob)) of
        {_, V} -> V;
        false -> <<>>
    end.

%% ═══ helpers ═════════════════════════════════════════════════════════════════

bin(B) when is_binary(B) -> B;
bin(L) when is_list(L) -> list_to_binary(L);
bin(A) when is_atom(A) -> atom_to_binary(A, utf8);
bin(I) when is_integer(I) -> integer_to_binary(I).

%% A value that carried a `;` or a `|` would make the blob unparseable. The
%% botopink half REFUSES such a path at startup; a certificate's own subject is
%% not under rakun's control, so the two characters are replaced there rather
%% than refused — an operator cannot move a CA's distinguished name.
scrub(B) ->
    binary:replace(binary:replace(B, <<";">>, <<" ">>, [global]),
                   <<"|">>, <<" ">>, [global]).

join(_Sep, []) -> <<>>;
join(Sep, [H | T]) ->
    lists:foldl(fun(X, Acc) -> <<Acc/binary, Sep/binary, X/binary>> end, H, T).

to_int(<<>>) -> 0;
to_int(B) when is_binary(B) ->
    case string:to_integer(binary_to_list(B)) of
        {error, _} -> 0;
        {N, _} -> N
    end;
to_int(N) when is_integer(N) -> N.
