%% rakun_client — the host half of `rakun-client` (front 13).
%%
%% What is here and why it is not botopink:
%%   * address work the language has no primitive for — resolving a name to
%%     EVERY address it answers (`inet:getaddrs/2`, both families), parsing and
%%     comparing IPv4/IPv6 addresses against CIDR ranges;
%%   * URL parsing and reference resolution (`uri_string`), because a redirect
%%     `Location` is a relative reference and resolving one by hand is where
%%     clients grow bugs;
%%   * reading an HTTP/1.1 response head (`erlang:decode_packet/3`) and
%%     de-chunking a body, over the bytes botopink already received — this module
%%     opens no socket and never reads one;
%%   * the TLS connect to a CHECKED address (`tls_connect/5`, the one socket
%%     call in the member, see its comment) and the soft cache seam's slot.
%%
%% Every text crossing the boundary is a binary; `""` is the "no answer" value.

-module(rakun_client).
-compile(nowarn_deprecated_catch).

-export([resolve/1, in_cidr/2, valid_cidr/1, normalize/1]).
-export([url_parts/1, resolve_url/2]).
-export([wire_complete/2, wire_status/1, wire_headers/1, wire_header/2, wire_body/1,
         byte_length/1, header_get/2]).
-export([tls_connect/5, no_handle/0, now_ms/0, encode_segment/1]).
-export([cache_install/1, cache_uninstall/0, cache_present/0, cache_through/5]).

-define(CACHE, rakun_client_response_cache).

%% ── addresses ──────────────────────────────────────────────────────────────

%% Every address `Host` answers, `\n`-joined, IPv4 first. A literal address
%% answers itself (normalised). A name that resolves to nothing answers `""`.
resolve(Host0) ->
    Host = strip_brackets(binary_to_list(Host0)),
    case inet:parse_address(Host) of
        {ok, Addr} ->
            ntoa(Addr);
        {error, _} ->
            V4 = case inet:getaddrs(Host, inet) of {ok, A} -> A; _ -> [] end,
            V6 = case inet:getaddrs(Host, inet6) of {ok, B} -> B; _ -> [] end,
            join([ntoa(X) || X <- dedup(V4 ++ V6)])
    end.

%% Is `Addr` inside `Cidr`? An IPv4-mapped IPv6 address (`::ffff:a.b.c.d`) is
%% compared as the IPv4 address it carries, so the mapping is no way around an
%% IPv4 deny entry. A malformed side answers `false`.
in_cidr(Addr0, Cidr0) ->
    case {parse(Addr0), parse_cidr(Cidr0)} of
        {{ok, A}, {ok, Net, Bits}} when tuple_size(A) =:= tuple_size(Net) ->
            prefix(A, Bits) =:= prefix(Net, Bits);
        _ ->
            false
    end.

valid_cidr(Cidr) ->
    case parse_cidr(Cidr) of
        {ok, _, _} -> true;
        _ -> false
    end.

%% The canonical text of an address (`::FFFF:10.0.0.1` → `10.0.0.1`), `""`
%% when it is not one.
normalize(Addr) ->
    case parse(Addr) of
        {ok, A} -> ntoa(A);
        _ -> <<>>
    end.

parse(Bin) ->
    case inet:parse_address(strip_brackets(binary_to_list(Bin))) of
        {ok, {0, 0, 0, 0, 0, 16#ffff, Hi, Lo}} ->
            {ok, {Hi bsr 8, Hi band 255, Lo bsr 8, Lo band 255}};
        {ok, A} ->
            {ok, A};
        Err ->
            Err
    end.

parse_cidr(Bin) ->
    case binary:split(string:trim(Bin), <<"/">>) of
        [AddrBin, BitsBin] ->
            case {parse(AddrBin), catch binary_to_integer(BitsBin)} of
                {{ok, A}, Bits} when is_integer(Bits), Bits >= 0 ->
                    case Bits =< width(A) of
                        true -> {ok, A, Bits};
                        false -> error
                    end;
                _ ->
                    error
            end;
        [AddrBin] ->
            case parse(AddrBin) of
                {ok, A} -> {ok, A, width(A)};
                _ -> error
            end;
        _ ->
            error
    end.

width(A) when tuple_size(A) =:= 4 -> 32;
width(_) -> 128.

prefix(A, Bits) ->
    Bin = to_bits(A),
    <<P:Bits/bitstring, _/bitstring>> = Bin,
    P.

to_bits({A, B, C, D}) -> <<A:8, B:8, C:8, D:8>>;
to_bits({A, B, C, D, E, F, G, H}) -> <<A:16, B:16, C:16, D:16, E:16, F:16, G:16, H:16>>.

ntoa(A) -> list_to_binary(inet:ntoa(A)).

strip_brackets([$[ | Rest]) -> lists:takewhile(fun(C) -> C =/= $] end, Rest);
strip_brackets(S) -> S.

dedup(L) -> dedup(L, []).
dedup([], Acc) -> lists:reverse(Acc);
dedup([X | R], Acc) ->
    case lists:member(X, Acc) of
        true -> dedup(R, Acc);
        false -> dedup(R, [X | Acc])
    end.

join([]) -> <<>>;
join(L) -> iolist_to_binary(lists:join(<<"\n">>, L)).

%% ── URLs ───────────────────────────────────────────────────────────────────

%% `scheme\nhost\nport\ntarget` for an absolute http(s) URL, `""` otherwise.
%% `host` is bare (no brackets); `target` is the path (default `/`) plus the
%% query. The scheme is lowercased; the port defaults by scheme.
url_parts(Url) ->
    case catch uri_string:parse(Url) of
        #{scheme := S0, host := H} = M when H =/= <<>> ->
            S = string:lowercase(S0),
            Port = case maps:get(port, M, undefined) of
                       undefined when S =:= <<"https">> -> 443;
                       undefined -> 80;
                       P -> P
                   end,
            Path = case maps:get(path, M, <<>>) of <<>> -> <<"/">>; Pa -> Pa end,
            Target = case maps:get(query, M, undefined) of
                         undefined -> Path;
                         Q -> <<Path/binary, "?", Q/binary>>
                     end,
            case S of
                Known when Known =:= <<"http">>; Known =:= <<"https">> ->
                    iolist_to_binary([S, "\n", H, "\n", integer_to_binary(Port), "\n", Target]);
                _ ->
                    <<>>
            end;
        _ ->
            <<>>
    end.

%% A `Location` resolved against the URL that answered it.
resolve_url(Ref, Base) ->
    case catch uri_string:resolve(Ref, Base) of
        R when is_binary(R) -> R;
        R when is_list(R) -> unicode:characters_to_binary(R);
        _ -> <<>>
    end.

%% ── the response on the wire ───────────────────────────────────────────────

%% Has `Raw` a whole response? The head must be complete; then the body is
%% bounded by `Content-Length`, by the terminal chunk of a chunked body, or —
%% for a HEAD, a 1xx, 204 or 304 — absent. A response with neither length nor
%% chunking is complete only when the peer closes, which the caller sees.
wire_complete(Raw, IsHead) ->
    case split_head(Raw) of
        {ok, Status, Headers, Body} ->
            case no_body(Status, IsHead) of
                true -> true;
                false ->
                    case chunked(Headers) of
                        true -> dechunk(Body) =/= incomplete;
                        false ->
                            case content_length(Headers) of
                                undefined -> false;
                                N -> byte_size(Body) >= N
                            end
                    end
            end;
        _ ->
            false
    end.

wire_status(Raw) ->
    case split_head(Raw) of
        {ok, Status, _, _} -> Status;
        _ -> -1
    end.

%% The response headers as a JSON object, names lowercased; a repeated header
%% is joined with `, ` (RFC 9110 § 5.3).
wire_headers(Raw) ->
    case split_head(Raw) of
        {ok, _, Headers, _} ->
            iolist_to_binary(json:encode(merged(Headers)));
        _ ->
            <<"{}">>
    end.

wire_header(Raw, Name) ->
    case split_head(Raw) of
        {ok, _, Headers, _} -> maps:get(string:lowercase(Name), merged(Headers), <<>>);
        _ -> <<>>
    end.

%% The body: de-chunked when chunked, cut to `Content-Length` otherwise.
wire_body(Raw) ->
    case split_head(Raw) of
        {ok, _, Headers, Body} ->
            case chunked(Headers) of
                true ->
                    case dechunk(Body) of
                        incomplete -> Body;
                        B -> B
                    end;
                false ->
                    case content_length(Headers) of
                        undefined -> Body;
                        N when byte_size(Body) > N -> binary:part(Body, 0, N);
                        _ -> Body
                    end
            end;
        _ ->
            <<>>
    end.

byte_length(S) -> byte_size(S).

header_get(Json, Name) ->
    case catch json:decode(Json) of
        M when is_map(M) ->
            case maps:get(string:lowercase(Name), M, <<>>) of
                V when is_binary(V) -> V;
                _ -> <<>>
            end;
        _ ->
            <<>>
    end.

split_head(Raw) ->
    case erlang:decode_packet(http_bin, Raw, []) of
        {ok, {http_response, _, Status, _}, Rest} -> read_headers(Rest, Status, []);
        _ -> incomplete
    end.

read_headers(Bin, Status, Acc) ->
    case erlang:decode_packet(httph_bin, Bin, []) of
        {ok, {http_header, _, Field, _, Value}, Rest} ->
            read_headers(Rest, Status, [{string:lowercase(to_bin(Field)), Value} | Acc]);
        {ok, http_eoh, Rest} ->
            {ok, Status, lists:reverse(Acc), Rest};
        _ ->
            incomplete
    end.

merged(Headers) ->
    lists:foldl(fun({K, V}, M) ->
                        case maps:find(K, M) of
                            {ok, Prev} -> M#{K => <<Prev/binary, ", ", V/binary>>};
                            error -> M#{K => V}
                        end
                end, #{}, Headers).

to_bin(A) when is_atom(A) -> atom_to_binary(A, utf8);
to_bin(L) when is_list(L) -> list_to_binary(L);
to_bin(B) -> B.

no_body(_Status, true) -> true;
no_body(Status, _) when Status >= 100, Status < 200 -> true;
no_body(204, _) -> true;
no_body(304, _) -> true;
no_body(_, _) -> false.

chunked(Headers) ->
    lists:any(fun({<<"transfer-encoding">>, V}) -> binary:match(string:lowercase(V), <<"chunked">>) =/= nomatch;
                 (_) -> false end, Headers).

content_length(Headers) ->
    case lists:keyfind(<<"content-length">>, 1, Headers) of
        {_, V} -> case catch binary_to_integer(string:trim(V)) of
                      N when is_integer(N), N >= 0 -> N;
                      _ -> undefined
                  end;
        false -> undefined
    end.

dechunk(Bin) -> dechunk(Bin, []).

dechunk(Bin, Acc) ->
    case binary:split(Bin, <<"\r\n">>) of
        [SizeLine, Rest] ->
            SizeHex = hd(binary:split(SizeLine, <<";">>)),
            case catch binary_to_integer(string:trim(SizeHex), 16) of
                0 -> iolist_to_binary(lists:reverse(Acc));
                N when is_integer(N), byte_size(Rest) >= N + 2 ->
                    <<Chunk:N/binary, _CrLf:2/binary, Next/binary>> = Rest,
                    dechunk(Next, [Chunk | Acc]);
                _ -> incomplete
            end;
        _ ->
            incomplete
    end.

%% ── TLS to a checked address ───────────────────────────────────────────────

%% The one socket call in the member. std's `net.tlsConnect(host, …)` takes a
%% NAME and resolves it again inside the OTP connect, which is exactly the DNS
%% rebinding hole the address filter closes (front 13 rule 6): the address that
%% was checked must be the address that is dialled. So this connects to the
%% checked `Addr` and names `Host` only as SNI and as the identity the
%% certificate must carry. With a bundle, the options are front 74's
%% (`rakun_ssl:connect_options/2`); without one, the host's trust store and a
%% full hostname check — there is no unverified mode.
%%
%% The answer is the same `{ok, #{handle => S}}` std's `tlsConnect` answers, so
%% the caller wraps it in std's `TlsSocket` and uses std's `tlsSend`/`tlsRecv`/
%% `tlsClose` for everything after the handshake.
tls_connect(Addr, Port, Host, Bundle, Timeout) ->
    _ = application:ensure_all_started(ssl),
    HostS = binary_to_list(Host),
    Verify = case Bundle of
                 <<>> ->
                     [{verify, verify_peer},
                      {cacerts, public_key:cacerts_get()},
                      {server_name_indication, HostS},
                      {customize_hostname_check,
                       [{match_fun, public_key:pkix_verify_hostname_match_fun(https)}]}];
                 _ ->
                     rakun_ssl:connect_options(Bundle, Host)
             end,
    {ok, Ip} = inet:parse_address(binary_to_list(Addr)),
    Opts = [binary, {packet, raw}, {active, false} | Verify],
    case catch ssl:connect(Ip, Port, Opts, Timeout) of
        {ok, S} -> {ok, #{handle => S}};
        {error, R} -> {error, iolist_to_binary(io_lib:format("~p", [R]))};
        Other -> {error, iolist_to_binary(io_lib:format("~p", [Other]))}
    end.

no_handle() -> undefined.

now_ms() -> erlang:monotonic_time(millisecond).

%% A path segment value, percent-encoded byte by byte: everything but the
%% RFC 3986 unreserved set, so a `/`, `?` or `#` in a value can never change
%% the shape of the URL it is substituted into.
encode_segment(Bin) ->
    << <<(enc(C))/binary>> || <<C>> <= Bin >>.

enc(C) when C >= $a, C =< $z; C >= $A, C =< $Z; C >= $0, C =< $9;
            C =:= $-; C =:= $.; C =:= $_; C =:= $~ ->
    <<C>>;
enc(C) ->
    iolist_to_binary(io_lib:format("%~2.16.0B", [C])).

%% ── the soft cache seam ────────────────────────────────────────────────────
%%
%% Front 12 installs ONE through-function; with none installed a cached
%% request is a direct transport call. A `persistent_term` slot, because it is
%% written once at boot and read on every cached request.

cache_install(Fun) ->
    persistent_term:put(?CACHE, Fun),
    0.

cache_uninstall() ->
    _ = persistent_term:erase(?CACHE),
    0.

cache_present() ->
    persistent_term:get(?CACHE, undefined) =/= undefined.

cache_through(Name, Parts, Life, Tags, Load) ->
    case persistent_term:get(?CACHE, undefined) of
        undefined -> Load();
        Fun -> Fun(Name, Parts, Life, Tags, Load)
    end.
