%%% rakun-mail — the host half of front 85: MIME composition, the SMTP client
%%% over gen_tcp / OTP ssl, the in-VM queue with its bounded sender, and the
%%% health probe.
%%%
%%% TRANSPORT. The default transport is written here over `gen_tcp` and OTP's
%%% `ssl` — both in the standard distribution — for the reason front 04 wrote
%%% its listener over `gen_tcp` rather than cowboy: a sidecar is loaded with no
%%% code path beyond the output directory, so `gen_smtp_client` would compile
%%% and then be `undef` on every machine that has not installed it.
%%% `rakun.mail.transport=gen_smtp` names the adapter module
%%% `rakun_mail_gen_smtp`; `transport_problem/1` refuses the boot when it is not
%%% loadable, and nothing falls back.
%%%
%%% CREDENTIALS never reach a log line, an error or a health detail: a failure
%%% names the SMTP stage and the server's reply, never the AUTH line.

-module(rakun_mail).
-compile(nowarn_deprecated_catch).
-export([compose/2, envelope_rcpts/1, address_of/1, send/2, probe/2, transport_problem/1,
         enqueue/4, configure/2, queue_stats/0, dead_letters/0, reset_queue/0, pending/0,
         pack/3, deliver_packed/2, header_encode/1, qp/1, dot_stuff/1, plain_of_html/1,
         log_lines/0]).

-define(CRLF, <<"\r\n">>).

%% ═══ composition ═════════════════════════════════════════════════════════════
%% `Mail` is the botopink record: {Tag, From, To, Cc, Bcc, ReplyTo, Subject,
%% Text, Html, Attachments, Headers}; an attachment {Tag, Filename,
%% ContentType, Path, Inline, Cid}. `Domain` names the Message-ID's right side.

compose(Mail, Domain) ->
    {_, From, To, Cc, _Bcc, ReplyTo, Subject, Text0, Html, Atts, Extra} = Mail,
    Text = case {Text0, Html} of
               {<<>>, <<>>} -> <<>>;
               {<<>>, _} -> plain_of_html(Html);
               _ -> Text0
           end,
    Inline = [A || A <- Atts, element(5, A) =:= true],
    Attached = [A || A <- Atts, element(5, A) =/= true],
    Parts0 = alternative(Text, Html, Inline),
    Body = case Attached of
               [] -> Parts0;
               _ -> multipart(<<"mixed">>, [Parts0 | [attachment(A) || A <- Attached]])
           end,
    {BodyHeaders, BodyText} = Body,
    Headers = lists:flatten([
        {<<"Date">>, date_header()},
        {<<"From">>, address_list([From])},
        [{<<"To">>, address_list(To)} || To =/= []],
        [{<<"Cc">>, address_list(Cc)} || Cc =/= []],
        [{<<"Reply-To">>, address_list([ReplyTo])} || ReplyTo =/= <<>>],
        {<<"Subject">>, header_encode(Subject)},
        {<<"Message-ID">>, <<"<", (hex(crypto:strong_rand_bytes(12)))/binary, "@", Domain/binary, ">">>},
        {<<"MIME-Version">>, <<"1.0">>},
        [{K, header_encode(V)} || {K, V} <- Extra],
        BodyHeaders]),
    iolist_to_binary([[K, <<": ">>, V, ?CRLF] || {K, V} <- Headers] ++ [?CRLF, BodyText]).

%% {Headers, Body} of the text/html/inline structure.
alternative(Text, <<>>, _) -> text_part(<<"text/plain">>, Text);
alternative(Text, Html, []) ->
    multipart(<<"alternative">>, [text_part(<<"text/plain">>, Text), text_part(<<"text/html">>, Html)]);
alternative(Text, Html, Inline) ->
    Related = multipart(<<"related">>, [text_part(<<"text/html">>, Html) | [attachment(A) || A <- Inline]]),
    multipart(<<"alternative">>, [text_part(<<"text/plain">>, Text), Related]).

text_part(Type, Text) ->
    {[{<<"Content-Type">>, <<Type/binary, "; charset=utf-8">>},
      {<<"Content-Transfer-Encoding">>, <<"quoted-printable">>}], qp(Text)}.

attachment({_, Filename, ContentType, Path, Inline, Cid}) ->
    Bytes = case file:read_file(unicode:characters_to_list(Path)) of
                {ok, B} -> B;
                {error, R} -> erlang:error({panic, iolist_to_binary(["rakun mail: attachment ", Path, " cannot be read (", atom_to_list(R), ")"])})
            end,
    Name = quoted_param(Filename),
    Disp = case Inline of true -> <<"inline">>; _ -> <<"attachment">> end,
    Headers = [{<<"Content-Type">>, <<ContentType/binary, "; name=", Name/binary>>},
               {<<"Content-Transfer-Encoding">>, <<"base64">>},
               {<<"Content-Disposition">>, <<Disp/binary, "; filename=", Name/binary>>}]
        ++ [{<<"Content-ID">>, <<"<", Cid/binary, ">">>} || Inline =:= true, Cid =/= <<>>],
    {Headers, wrap(base64:encode(Bytes), 76)}.

%% A boundary that occurs in no part's rendered content — derived, then checked.
multipart(Kind, Parts) ->
    Rendered = [iolist_to_binary([[[K, <<": ">>, V, ?CRLF] || {K, V} <- H], ?CRLF, B]) || {H, B} <- Parts],
    Boundary = boundary(Rendered),
    Body = iolist_to_binary([[<<"--">>, Boundary, ?CRLF, R, ?CRLF] || R <- Rendered] ++ [<<"--">>, Boundary, <<"--">>, ?CRLF]),
    {[{<<"Content-Type">>, <<"multipart/", Kind/binary, "; boundary=\"", Boundary/binary, "\"">>}], Body}.

boundary(Rendered) ->
    B = <<"=_rakun_", (hex(crypto:strong_rand_bytes(12)))/binary>>,
    case lists:any(fun(R) -> binary:match(R, B) =/= nomatch end, Rendered) of
        true -> boundary(Rendered);
        false -> B
    end.

hex(B) -> binary:encode_hex(B, lowercase).

wrap(B, N) -> iolist_to_binary(wrap(B, N, [])).
wrap(B, N, Acc) when byte_size(B) =< N -> lists:reverse([<<"\r\n">>, B | Acc]);
wrap(B, N, Acc) -> <<Line:N/binary, Rest/binary>> = B, wrap(Rest, N, [<<"\r\n">>, Line | Acc]).

date_header() ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:universal_time(),
    Days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
    Months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
    Dow = lists:nth(calendar:day_of_the_week(Y, Mo, D), Days),
    iolist_to_binary(io_lib:format("~s, ~2..0B ~s ~4..0B ~2..0B:~2..0B:~2..0B +0000", [Dow, D, lists:nth(Mo, Months), Y, H, Mi, S])).

%% ── addresses ────────────────────────────────────────────────────────────────

%% "Name <a@b>" or "a@b" -> {Name, Addr}.
split_address(A0) ->
    A = string:trim(A0),
    case binary:match(A, <<"<">>) of
        nomatch -> {<<>>, A};
        {P, _} ->
            Name = string:trim(binary:part(A, 0, P)),
            Rest = binary:part(A, P + 1, byte_size(A) - P - 1),
            Addr = hd(binary:split(Rest, <<">">>)),
            {unquote(Name), string:trim(Addr)}
    end.

unquote(<<"\"", _/binary>> = N) when byte_size(N) >= 2 ->
    Inner = binary:part(N, 1, byte_size(N) - 2),
    binary:replace(binary:replace(Inner, <<"\\\"">>, <<"\"">>, [global]), <<"\\\\">>, <<"\\">>, [global]);
unquote(N) -> N.

address_of(A) -> element(2, split_address(A)).

address_list(As) ->
    iolist_to_binary(lists:join(<<", ">>, [render_address(split_address(A)) || A <- As])).

render_address({<<>>, Addr}) -> Addr;
render_address({Name, Addr}) ->
    Shown = case ascii(Name) of
                false -> header_encode(Name);
                true ->
                    case needs_quotes(Name) of
                        true -> <<"\"", (escape_quoted(Name))/binary, "\"">>;
                        false -> Name
                    end
            end,
    <<Shown/binary, " <", Addr/binary, ">">>.

needs_quotes(N) -> lists:any(fun(C) -> lists:member(C, "()<>[]:;@\\,.\"") end, binary_to_list(N)).

escape_quoted(N) -> binary:replace(binary:replace(N, <<"\\">>, <<"\\\\">>, [global]), <<"\"">>, <<"\\\"">>, [global]).

quoted_param(F) ->
    case ascii(F) of
        true -> <<"\"", (escape_quoted(F))/binary, "\"">>;
        false -> <<"\"", (header_encode(F))/binary, "\"">>
    end.

ascii(B) -> lists:all(fun(C) -> C < 128 end, binary_to_list(B)).

%% RFC 2047: a value with a non-ASCII byte, or longer than 78, becomes
%% `=?UTF-8?B?…?=` words of at most 75 characters, folded with CRLF SP; an
%% ASCII value that fits is left alone. Words split on codepoint boundaries.
header_encode(V) ->
    case ascii(V) andalso byte_size(V) =< 78 of
        true -> V;
        false ->
            Words = [<<"=?UTF-8?B?", (base64:encode(Chunk))/binary, "?=">> || Chunk <- chunks(V, 45)],
            iolist_to_binary(lists:join(<<"\r\n ">>, Words))
    end.

%% UTF-8 chunks of at most N bytes, never splitting a codepoint.
chunks(<<>>, _) -> [];
chunks(B, N) -> {C, R} = take(B, N, <<>>), [C | chunks(R, N)].
take(<<>>, _, Acc) -> {Acc, <<>>};
take(<<Cp/utf8, Rest/binary>> = B, N, Acc) ->
    Enc = <<Cp/utf8>>,
    case byte_size(Acc) + byte_size(Enc) > N of
        true -> {Acc, B};
        false -> take(Rest, N, <<Acc/binary, Enc/binary>>)
    end;
take(<<X, Rest/binary>>, N, Acc) -> take(Rest, N, <<Acc/binary, X>>).

%% ── quoted-printable (RFC 2045), lines of at most 76 ─────────────────────────

qp(Text) ->
    Lines = binary:split(binary:replace(Text, <<"\r\n">>, <<"\n">>, [global]), <<"\n">>, [global]),
    iolist_to_binary(lists:join(?CRLF, [qp_line(L) || L <- Lines])).

qp_line(L) ->
    Tokens = qp_tokens(binary_to_list(L), byte_size(L)),
    soft_wrap(Tokens, 0, []).

qp_tokens([], _) -> [];
qp_tokens([C], _) when C =:= $\s; C =:= $\t -> [enc(C)];
qp_tokens([C | Rest], N) when C =:= $=; C > 126; C < 32, C =/= $\t -> [enc(C) | qp_tokens(Rest, N)];
qp_tokens([C | Rest], N) -> [[C] | qp_tokens(Rest, N)].

enc(C) -> io_lib:format("=~2.16.0B", [C]).

soft_wrap([], _, Acc) -> lists:reverse(Acc);
soft_wrap([T | Rest], Len, Acc) ->
    TL = length(lists:flatten(T)),
    case Len + TL > 75 of
        true -> soft_wrap(Rest, TL, [T, "=\r\n" | Acc]);
        false -> soft_wrap(Rest, Len + TL, [T | Acc])
    end.

%% A line starting with `.` gains a second dot (RFC 5321 §4.5.2).
dot_stuff(Msg) ->
    Lines = binary:split(Msg, ?CRLF, [global]),
    iolist_to_binary(lists:join(?CRLF, [case L of <<".", _/binary>> -> <<".", L/binary>>; _ -> L end || L <- Lines])).

%% The plain part generated from an HTML body the caller gave without text.
plain_of_html(Html) ->
    S1 = re:replace(Html, "<\\s*(br|/p|/div|/li|/h[1-6])[^>]*>", "\n", [global, caseless, {return, binary}, unicode]),
    S2 = re:replace(S1, "<(script|style)[^>]*>.*?</\\1>", "", [global, caseless, dotall, {return, binary}, unicode]),
    S3 = re:replace(S2, "<[^>]*>", "", [global, {return, binary}, unicode]),
    S4 = lists:foldl(fun({E, R}, Acc) -> binary:replace(Acc, E, R, [global]) end, S3,
                     [{<<"&lt;">>, <<"<">>}, {<<"&gt;">>, <<">">>}, {<<"&quot;">>, <<"\"">>}, {<<"&#39;">>, <<"'">>}, {<<"&nbsp;">>, <<" ">>}, {<<"&amp;">>, <<"&">>}]),
    S5 = re:replace(S4, "[ \\t]+", " ", [global, {return, binary}, unicode]),
    string:trim(re:replace(S5, "\\n\\s*\\n+", "\n\n", [global, {return, binary}, unicode])).

%% Every envelope recipient: to, cc and bcc, bare addresses.
envelope_rcpts(Mail) ->
    {_, _, To, Cc, Bcc, _, _, _, _, _, _} = Mail,
    [address_of(A) || A <- To ++ Cc ++ Bcc].

%% ═══ the SMTP client ═════════════════════════════════════════════════════════
%% `Server` is the botopink record {Tag, Host, Port, Username, Password,
%% TlsMode, Bundle, ConnectMs, ReadMs, WriteMs}; TlsMode an atom-ish variant.
%% Answers `ok`, or `<kind>\t<reason>` with kind `permanent` or `retryable`.

send(Server, {From, Rcpts, Msg}) ->
    run(Server, fun(C) ->
                        ok = step(C, [<<"MAIL FROM:<">>, From, <<">">>], [250], <<"MAIL FROM">>),
                        [ok = step(C, [<<"RCPT TO:<">>, R, <<">">>], [250, 251], <<"RCPT TO">>) || R <- Rcpts],
                        ok = step(C, <<"DATA">>, [354], <<"DATA">>),
                        ok = write_chunked(C, <<(dot_stuff(Msg))/binary, "\r\n.\r\n">>),
                        ok = expect(C, [250], <<"the end of DATA">>),
                        _ = (catch step(C, <<"QUIT">>, [221], <<"QUIT">>)),
                        ok
                end, true).

%% EHLO (and STARTTLS) then QUIT, sending nothing. `UP\t<tls>` or `DOWN\t<reason>`.
probe(Server, TimeoutMs) ->
    Short = setelement(8, setelement(9, setelement(10, Server, TimeoutMs), TimeoutMs), TimeoutMs),
    Self = self(),
    Ref = make_ref(),
    Pid = spawn(fun() -> Self ! {Ref, run(Short, fun(C) -> _ = (catch step(C, <<"QUIT">>, [221], <<"QUIT">>)), {tls, element(1, C)} end, false)} end),
    receive
        {Ref, {tls, Kind}} -> iolist_to_binary(["UP\t", case Kind of ssl -> "true"; _ -> "false" end]);
        {Ref, Err} -> iolist_to_binary(["DOWN\t", Err])
    after TimeoutMs + 500 ->
        exit(Pid, kill),
        <<"DOWN\tretryable\tthe health check timed out">>
    end.

tls_mode(Server) ->
    case element(6, Server) of
        M when is_atom(M) -> M;
        T when is_tuple(T) -> element(1, T);
        B when is_binary(B) -> binary_to_atom(B)
    end.

run(Server, Work, Auth) ->
    {_, Host, Port, User, Pass, _, Bundle, ConnectMs, ReadMs, WriteMs} = Server,
    Mode = mode_name(tls_mode(Server)),
    HostS = binary_to_list(Host),
    Base = [binary, {packet, line}, {active, false}, {send_timeout, WriteMs}, {send_timeout_close, true}],
    Conn = case Mode of
               implicit ->
                   _ = application:ensure_all_started(ssl),
                   case ssl:connect(HostS, Port, Base ++ tls_opts(Bundle, Host), ConnectMs) of
                       {ok, S} -> {ssl, S};
                       E -> E
                   end;
               _ ->
                   case gen_tcp:connect(HostS, Port, Base, ConnectMs) of
                       {ok, S} -> {gen_tcp, S};
                       E -> E
                   end
           end,
    case Conn of
        {error, timeout} -> <<"retryable\tconnect-timeout: no connection within ", (integer_to_binary(ConnectMs))/binary, " ms">>;
        {error, R} -> iolist_to_binary(["retryable\tconnect: ", io_lib:format("~p", [R])]);
        C0 ->
            put(rakun_mail_read_ms, ReadMs),
            try
                ok = expect(C0, [220], <<"the greeting">>),
                {C1, Caps} = hello(C0, Host, Mode, Bundle),
                ok = case Auth andalso User =/= <<>> of
                         true -> auth(C1, Caps, User, Pass);
                         false -> ok
                     end,
                R1 = Work(C1),
                close(C1),
                R1
            catch
                throw:{smtp, Kind, Reason} -> close(C0), iolist_to_binary([atom_to_binary(Kind), "\t", Reason])
            end
    end.

mode_name(none) -> none;
mode_name('None') -> none;
mode_name('StartTls') -> starttls;
mode_name(starttls) -> starttls;
mode_name('Implicit') -> implicit;
mode_name(implicit) -> implicit;
mode_name(Other) ->
    Name = string:lowercase(atom_to_list(Other)),
    Leaf = case string:split(Name, "__v__", trailing) of [_, L] -> L; _ -> Name end,
    case Leaf of
        "starttls" -> starttls;
        "implicit" -> implicit;
        _ -> none
    end.

tls_opts(<<>>, Host) ->
    [{verify, verify_peer}, {cacerts, public_key:cacerts_get()}, {server_name_indication, binary_to_list(Host)},
     {customize_hostname_check, [{match_fun, public_key:pkix_verify_hostname_match_fun(https)}]}];
tls_opts(Bundle, Host) -> rakun_ssl:connect_options(Bundle, Host).

hello(C, Host, Mode, Bundle) ->
    Caps = ehlo(C),
    case Mode of
        starttls ->
            case lists:member(<<"STARTTLS">>, [string:uppercase(hd(string:split(L, " "))) || L <- Caps]) of
                false -> throw({smtp, permanent, <<"STARTTLS is required (rakun.mail.tls=starttls) and the server does not advertise it - no key permits continuing in the clear">>});
                true ->
                    ok = step(C, <<"STARTTLS">>, [220], <<"STARTTLS">>),
                    {gen_tcp, S} = C,
                    _ = application:ensure_all_started(ssl),
                    case ssl:connect(S, tls_opts(Bundle, Host), get(rakun_mail_read_ms)) of
                        {ok, T} -> C2 = {ssl, T}, {C2, ehlo(C2)};
                        {error, R} -> throw({smtp, retryable, iolist_to_binary(["the TLS negotiation failed: ", io_lib:format("~p", [R])])})
                    end
            end;
        _ -> {C, Caps}
    end.

ehlo(C) ->
    ok = write(C, <<"EHLO rakun.local\r\n">>),
    case reply(C, <<"EHLO">>) of
        {250, Lines} -> Lines;
        {Code, Lines} -> throw({smtp, kind(Code), stage_reason(<<"EHLO">>, Code, Lines)})
    end.

auth(C, Caps, User, Pass) ->
    Mechs = lists:append([string:lexemes(string:uppercase(L), " ") || L <- Caps, string:prefix(string:uppercase(L), "AUTH") =/= nomatch]),
    case {lists:member(<<"PLAIN">>, Mechs), lists:member(<<"LOGIN">>, Mechs)} of
        {true, _} ->
            ok = write(C, [<<"AUTH PLAIN ">>, base64:encode(<<0, User/binary, 0, Pass/binary>>), ?CRLF]),
            expect(C, [235], <<"AUTH PLAIN">>);
        {false, true} ->
            ok = step(C, <<"AUTH LOGIN">>, [334], <<"AUTH LOGIN">>),
            ok = write(C, [base64:encode(User), ?CRLF]),
            ok = expect(C, [334], <<"AUTH LOGIN">>),
            ok = write(C, [base64:encode(Pass), ?CRLF]),
            expect(C, [235], <<"AUTH LOGIN">>);
        _ -> throw({smtp, permanent, <<"AUTH: the server offers neither PLAIN nor LOGIN">>})
    end.

step(C, Line, Ok, Stage) ->
    ok = write(C, [Line, ?CRLF]),
    expect(C, Ok, Stage).

expect(C, Ok, Stage) ->
    {Code, Lines} = reply(C, Stage),
    case lists:member(Code, Ok) of
        true -> ok;
        false -> throw({smtp, kind(Code), stage_reason(Stage, Code, Lines)})
    end.

kind(Code) when Code >= 500 -> permanent;
kind(_) -> retryable.

stage_reason(Stage, Code, Lines) ->
    iolist_to_binary([Stage, " answered ", integer_to_binary(Code), " ", lists:join(" ", Lines)]).

write({M, S}, Data) ->
    case M:send(S, Data) of
        ok -> ok;
        {error, timeout} -> throw({smtp, retryable, <<"write-timeout: the server stopped reading">>});
        {error, R} -> throw({smtp, retryable, iolist_to_binary(["write: ", io_lib:format("~p", [R])])})
    end.

%% The DATA body in 64 KiB writes: the driver queues one write whole, so only a
%% write issued while the queue is full can meet `send_timeout`.
write_chunked(C, B) when byte_size(B) =< 65536 -> write(C, B);
write_chunked(C, B) ->
    <<Chunk:65536/binary, Rest/binary>> = B,
    ok = write(C, Chunk),
    write_chunked(C, Rest).

reply(C, Stage) -> reply(C, Stage, []).
reply({M, S} = C, Stage, Acc) ->
    case M:recv(S, 0, get(rakun_mail_read_ms)) of
        {ok, Line0} ->
            Line = strip_eol(Line0),
            case Line of
                <<D1, D2, D3, Sep, Rest/binary>> when Sep =:= $-; Sep =:= $\s ->
                    Code = list_to_integer([D1, D2, D3]),
                    case Sep of
                        $- -> reply(C, Stage, [Rest | Acc]);
                        $\s -> {Code, lists:reverse([Rest | Acc])}
                    end;
                <<D1, D2, D3>> -> {list_to_integer([D1, D2, D3]), lists:reverse(Acc)};
                _ -> throw({smtp, retryable, iolist_to_binary([Stage, ": an unreadable reply"])})
            end;
        {error, timeout} -> throw({smtp, retryable, iolist_to_binary(["read-timeout: no reply to ", Stage, " within ", integer_to_binary(get(rakun_mail_read_ms)), " ms"])});
        {error, R} -> throw({smtp, retryable, iolist_to_binary([Stage, ": ", io_lib:format("~p", [R])])})
    end.

close({M, S}) -> catch M:close(S).

transport_problem(<<"gen_smtp">>) ->
    case code:ensure_loaded(rakun_mail_gen_smtp) of
        {module, _} -> <<>>;
        _ -> <<"rakun mail: rakun.mail.transport=gen_smtp names the adapter module rakun_mail_gen_smtp, which is not loadable - install it or remove the key (there is no fallback to the built-in client)">>
    end;
transport_problem(T) when T =:= <<>>; T =:= <<"smtp">> -> <<>>;
transport_problem(T) -> <<"rakun mail: unknown rakun.mail.transport `", T/binary, "` - smtp or gen_smtp">>.

%% ═══ the queue ═══════════════════════════════════════════════════════════════
%% One sender process owns the queue; at most `concurrency` deliveries run at
%% once. A retryable failure waits `backoff * 2^(n-1)` then retries, to
%% `attempts`; past it, or on a permanent failure, the message is dead-lettered
%% with its last error. `send` never opens a socket: it composes and hands over.

configure(Server, Policy) ->
    persistent_term:put(rakun_mail_server, Server),
    persistent_term:put(rakun_mail_policy, Policy),
    0.

sender() ->
    case whereis(rakun_mail_sender) of
        undefined ->
            Me = self(),
            spawn(fun() ->
                          case catch register(rakun_mail_sender, self()) of
                              true -> Me ! ready, loop(#{queue => [], busy => 0, peak => 0, sent => 0, dead => [], log => []});
                              _ -> Me ! ready
                          end
                  end),
            receive ready -> ok after 1000 -> ok end,
            whereis(rakun_mail_sender);
        P -> P
    end.

enqueue(Id, From, Rcpts, Msg) ->
    sender() ! {enqueue, #{id => Id, env => {address_of(From), Rcpts, Msg}, attempts => 0, due => 0}},
    Id.

call(Req) ->
    P = sender(),
    Ref = make_ref(),
    P ! {Req, self(), Ref},
    receive {Ref, R} -> R after 5000 -> undefined end.

queue_stats() ->
    #{busy := B, peak := P, sent := S, queue := Q, dead := D} = call(stats),
    iolist_to_binary(io_lib:format("sent=~p queued=~p busy=~p peak=~p dead=~p", [S, length(Q), B, P, length(D)])).
pending() -> #{queue := Q, busy := B} = call(stats), length(Q) + B.
dead_letters() -> #{dead := D} = call(stats), [iolist_to_binary([Id, "\t", Why]) || {Id, Why} <- lists:reverse(D)].
reset_queue() -> call(reset), 0.
log_lines() -> #{log := L} = call(stats), lists:reverse(L).

policy() -> persistent_term:get(rakun_mail_policy, {2, 3, 1000}).

loop(St) ->
    St1 = dispatch(St),
    receive
        {enqueue, Job} -> loop(St1#{queue := maps:get(queue, St1) ++ [Job]});
        {done, Job, Result} -> loop(finish(St1#{busy := maps:get(busy, St1) - 1}, Job, Result));
        {stats, From, Ref} -> From ! {Ref, St1}, loop(St1);
        {reset, From, Ref} -> From ! {Ref, ok}, loop(St1#{queue := [], peak := maps:get(busy, St1), sent := 0, dead := [], log := []});
        tick -> loop(St1)
    after 50 -> loop(St1)
    end.

dispatch(#{queue := Q, busy := B} = St) ->
    {Conc, _, _} = policy(),
    Now = erlang:system_time(millisecond),
    case lists:splitwith(fun(J) -> maps:get(due, J) > Now end, Q) of
        {_, []} -> St;
        {Before, [Job | After]} when B < Conc ->
            Me = self(),
            Server = persistent_term:get(rakun_mail_server),
            spawn(fun() ->
                          R = try send(Server, maps:get(env, Job)) catch _:E -> iolist_to_binary(["retryable\t", io_lib:format("~p", [E])]) end,
                          Me ! {done, Job, R}
                  end),
            NB = B + 1,
            dispatch(St#{queue := Before ++ After, busy := NB, peak := erlang:max(NB, maps:get(peak, St))});
        _ -> St
    end.

finish(St, _Job, ok) -> St#{sent := maps:get(sent, St) + 1};
finish(St, Job, Err) ->
    {_, Tries, Backoff} = policy(),
    N = maps:get(attempts, Job) + 1,
    [Kind | _] = binary:split(Err, <<"\t">>),
    Why = case binary:split(Err, <<"\t">>) of [_, W] -> W; _ -> Err end,
    Log = [iolist_to_binary(["rakun mail: ", maps:get(id, Job), " attempt ", integer_to_binary(N), " failed: ", Why]) | maps:get(log, St)],
    logger:warning("~ts", [hd(Log)]),
    case Kind =:= <<"retryable">> andalso N < Tries of
        true ->
            Due = erlang:system_time(millisecond) + Backoff * (1 bsl (N - 1)),
            St#{queue := maps:get(queue, St) ++ [Job#{attempts := N, due := Due}], log := Log};
        false -> St#{dead := [{maps:get(id, Job), Err} | maps:get(dead, St)], log := Log}
    end.

%% ═══ the outbox payload (front 83) ═══════════════════════════════════════════

pack(From, Rcpts, Msg) -> base64:encode(term_to_binary({address_of(From), Rcpts, Msg})).

deliver_packed(Server, Payload) ->
    case send(Server, binary_to_term(base64:decode(Payload), [safe])) of
        ok -> <<>>;
        Err -> Err
    end.

strip_eol(B) ->
    case B of
        <<>> -> B;
        _ ->
            case binary:last(B) of
                C when C =:= $\r; C =:= $\n -> strip_eol(binary:part(B, 0, byte_size(B) - 1));
                _ -> B
            end
    end.
