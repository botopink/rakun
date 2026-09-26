%%% rakun-web — the static-file server, BEAM half (front 82).
%%%
%%% WHAT LIVES HERE AND WHY. "Bytes never enter botopink": a file body goes from
%%% disk to the socket in this module and no botopink value ever holds it. The
%%% bp side (`static.bp`) decides everything a policy decides — which root, which
%%% status, which headers, which byte range, which pre-compressed variant — and
%%% hands this module a PATH. What this module does is what botopink cannot do
%%% without holding bytes:
%%%
%%%   * `decode/1` — one percent-decode, on bytes;
%%%   * `locate/3` — join, canonicalise (a hand-rolled realpath: OTP has none),
%%%     the containment check against the canonical root, the index-file step and
%%%     the `stat`, in the README's order;
%%%   * `hash_file/1` — the SHA-256 of a file, streamed in 64 KiB reads, equal
%%%     to std's `hash.sha256` of the same content (a test pins the equality);
%%%   * `send_file/5` / `send_head/2` — the response head, then the body through
%%%     `file:sendfile/5` on a gen_tcp socket or 64 KiB `pread`s on a TLS one.
%%%
%%% THE CONNECTION. Front 04's listener records the connection's socket in the
%%% process dictionary (`rakun_conn_socket`, transport in `rakun_transport`) and
%%% skips its own response when the request is marked `rakun_streamed` — the
%%% seam front 23's chunk writer uses. This module writes the head itself (the
%%% queued reply headers, i.e. every `withHeader` an entry made BEFORE the static
%%% entry answered, plus `Content-Length`) and marks the request streamed.
%%%
%%% THE FILESYSTEM-CALL COUNTER. Every call this module makes into `file` bumps
%%% one counter. "A traversal answers 404 without touching the disk" is the
%%% property under test, and only the counter can tell it from "answers 404".
%%%
%%% MODULE ATOM. `rakun_static`, never `static`: `shipErlSidecars` silently
%%% skips a qualifier atom equal to an emitted module, and rakun-web emits
%%% `static`.
-module(rakun_static).

-include_lib("kernel/include/file.hrl").

%% the root registry
-export([root_add/1, root_count/0, root_at/1, root_reset/0]).
%% resolution
-export([decode_ok/1, decode/1, plain_ok/1, locate/3, variant/3, hash_file/1]).
%% dates
-export([http_date/1, parse_http_date/1]).
%% the wire
-export([send_file/5, send_head/2, has_socket/0]).
%% the counter
-export([fs_calls/0, fs_reset/0]).
%% reachable for a test
-export([ensure/0, realpath/1]).

-define(ROOTS, rakun_static_roots).   %% ordered_set: {Seq, Root}
-define(SEQ, rakun_static_seq).       %% set: {Key, Integer}
-define(HASHES, rakun_static_hashes). %% set: {{Path, Size, Mtime}, Hex}
-define(OWNER, rakun_static_owner).
-define(CHUNK, 65536).
-define(MAX_LINKS, 40).

%% ═══ lifecycle ═══════════════════════════════════════════════════════════════
%% An ETS table dies with its creator, and a registration runs in whatever
%% process called it — so a dedicated, registered owner process creates the
%% tables and stays alive (`rakun_chain`'s shape, for the same reason).

ensure() ->
    case ets:whereis(?ROOTS) of
        undefined -> boot();
        _ -> ok
    end.

boot() ->
    Caller = self(),
    Pid = spawn(fun() -> owner(Caller) end),
    Ref = erlang:monitor(process, Pid),
    receive
        {?OWNER, ready} -> erlang:demonitor(Ref, [flush]), ok;
        {'DOWN', Ref, process, Pid, _} -> ok
    after 5000 ->
        erlang:demonitor(Ref, [flush]), ok
    end.

owner(Caller) ->
    case catch erlang:register(?OWNER, self()) of
        true ->
            Common = [named_table, public, {read_concurrency, true}],
            _ = ets:new(?ROOTS, [ordered_set | Common]),
            _ = ets:new(?SEQ, [set | Common]),
            _ = ets:new(?HASHES, [set | Common]),
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

next_seq(Key) ->
    ets:update_counter(?SEQ, Key, {2, 1}, {Key, 0}).

%% ═══ the root registry ═══════════════════════════════════════════════════════
%% Registration order IS resolution order: roots are kept by a sequence number
%% and `root_at/1` answers them in that order.

root_add(Root) ->
    ensure(),
    Seq = next_seq(roots),
    true = ets:insert(?ROOTS, {Seq, Root}),
    ets:info(?ROOTS, size).

root_count() ->
    ensure(),
    ets:info(?ROOTS, size).

root_at(I) ->
    ensure(),
    {_Seq, Root} = lists:nth(I + 1, ets:tab2list(?ROOTS)),
    Root.

root_reset() ->
    ensure(),
    true = ets:delete_all_objects(?ROOTS),
    true = ets:delete_all_objects(?HASHES),
    0.

%% ═══ the counter ═════════════════════════════════════════════════════════════

fs() ->
    ensure(),
    _ = next_seq(fs_calls),
    ok.

fs_calls() ->
    ensure(),
    case ets:lookup(?SEQ, fs_calls) of
        [{_, N}] -> N;
        [] -> 0
    end.

fs_reset() ->
    ensure(),
    true = ets:insert(?SEQ, {fs_calls, 0}),
    0.

%% ═══ step 2: one percent-decode ══════════════════════════════════════════════
%% `decode_ok/1` is false when an escape is malformed, when the decoded bytes
%% carry a NUL, or when they still carry a `%XX` escape — a doubly-encoded path
%% (`%252e`) is refused, never decoded a second time. Each answers 400.

decode_ok(Raw) ->
    case pct(to_bin(Raw), <<>>) of
        {ok, Bin} ->
            binary:match(Bin, <<0>>) =:= nomatch andalso not still_encoded(Bin);
        error ->
            false
    end.

%% For a target an earlier entry already decoded: no NUL and no remaining
%% `%XX` escape — the checks a decode would have made, without decoding again.
plain_ok(Path) ->
    Bin = to_bin(Path),
    binary:match(Bin, <<0>>) =:= nomatch andalso not still_encoded(Bin).

decode(Raw) ->
    case pct(to_bin(Raw), <<>>) of
        {ok, Bin} -> Bin;
        error -> <<>>
    end.

pct(<<$%, A, B, Rest/binary>>, Acc) ->
    case hex(A) =/= error andalso hex(B) =/= error of
        true -> pct(Rest, <<Acc/binary, (hex(A) * 16 + hex(B))>>);
        false -> error
    end;
pct(<<$%, _/binary>>, _Acc) ->
    error;
pct(<<C, Rest/binary>>, Acc) ->
    pct(Rest, <<Acc/binary, C>>);
pct(<<>>, Acc) ->
    {ok, Acc}.

still_encoded(<<$%, A, B, Rest/binary>>) ->
    case hex(A) =/= error andalso hex(B) =/= error of
        true -> true;
        false -> still_encoded(<<B, Rest/binary>>)
    end;
still_encoded(<<_, Rest/binary>>) ->
    still_encoded(Rest);
still_encoded(<<>>) ->
    false.

hex(C) when C >= $0, C =< $9 -> C - $0;
hex(C) when C >= $a, C =< $f -> C - $a + 10;
hex(C) when C >= $A, C =< $F -> C - $A + 10;
hex(_) -> error.

%% ═══ steps 4–6: join, canonicalise, contain, index, stat ═════════════════════
%% `Rel` has already been vetted by botopink (no `..`, `.`, empty segment, NUL):
%% a traversal never reaches this function. What reaches it can still escape
%% through a SYMLINK, so the joined path is canonicalised — every component
%% resolved, links followed — BEFORE the `stat`, and must lie inside the
%% canonical root. Every failure answers `<<>>`, which botopink maps to 404: a
%% prober cannot tell "exists but refused" from "does not exist".
%%
%% Answers `<<"Canonical\tSize\tMtime\tIndexUsed">>` (`IndexUsed` is `1` when a
%% directory request resolved to its index file, `0` otherwise).

locate(Root, Rel, Index) ->
    case realpath(to_bin(Root)) of
        {ok, CRoot} ->
            case contained_file(CRoot, join(CRoot, to_bin(Rel))) of
                {file, Path, Info} ->
                    found(Path, Info, <<"0">>);
                {dir, Dir} when Index =/= <<>>, Index =/= "" ->
                    case contained_file(CRoot, join(Dir, to_bin(Index))) of
                        {file, Path, Info} -> found(Path, Info, <<"1">>);
                        _ -> <<>>
                    end;
                _ ->
                    <<>>
            end;
        error ->
            <<>>
    end.

found(Path, #file_info{size = Size, mtime = Mtime}, IndexUsed) ->
    iolist_to_binary([Path, $\t, integer_to_binary(Size), $\t, integer_to_binary(Mtime), $\t, IndexUsed]).

contained_file(CRoot, Joined) ->
    case realpath(Joined) of
        {ok, Canon} ->
            case inside(CRoot, Canon) of
                true ->
                    fs(),
                    case file:read_file_info(Canon, [{time, posix}]) of
                        {ok, #file_info{type = regular} = Info} -> {file, Canon, Info};
                        {ok, #file_info{type = directory}} -> {dir, Canon};
                        _ -> none
                    end;
                false ->
                    none
            end;
        error ->
            none
    end.

inside(CRoot, Canon) ->
    Canon =:= CRoot orelse
        binary:longest_common_prefix([Canon, <<CRoot/binary, "/">>]) =:= byte_size(CRoot) + 1
        orelse CRoot =:= <<"/">>.

join(Dir, <<>>) -> Dir;
join(Dir, Rel) -> <<Dir/binary, "/", Rel/binary>>.

%% A pre-compressed variant of `Path` (the canonical original): it must itself
%% resolve inside the canonical root, be a regular file, and be at least as new
%% as the original — a stale variant is a wrong answer, not a fast one.
%% Answers `<<"Canonical\tSize">>` or `<<>>`.
variant(Root, Path, MinMtime) ->
    case realpath(to_bin(Root)) of
        {ok, CRoot} ->
            case contained_file(CRoot, to_bin(Path)) of
                {file, Canon, #file_info{size = Size, mtime = M}} when M >= MinMtime ->
                    iolist_to_binary([Canon, $\t, integer_to_binary(Size)]);
                _ ->
                    <<>>
            end;
        error ->
            <<>>
    end.

%% realpath(3) by hand: every component of the absolute path resolved in turn,
%% a symlink replaced by its target and resolution restarted, at most
%% `?MAX_LINKS` links (a loop is `error`, not a hang). `..` inside a LINK TARGET
%% applies to the already-resolved prefix, which is what the kernel does.
realpath(Path) ->
    [_Slash | Parts] = filename:split(filename:absname(Path)),
    walk(Parts, <<"/">>, 0).

walk(_, _, N) when N > ?MAX_LINKS -> error;
walk([], Acc, _) -> {ok, Acc};
walk([<<".">> | T], Acc, N) -> walk(T, Acc, N);
walk([<<"..">> | T], Acc, N) -> walk(T, filename:dirname(Acc), N);
walk([C | T], Acc, N) ->
    Next = filename:join(Acc, C),
    fs(),
    case file:read_link_info(Next) of
        {ok, #file_info{type = symlink}} ->
            fs(),
            case file:read_link_all(Next) of
                {ok, Target0} ->
                    Target = to_bin(Target0),
                    Base = case filename:pathtype(Target) of
                               absolute -> Target;
                               _ -> filename:join(Acc, Target)
                           end,
                    [_ | More] = filename:split(Base),
                    walk(More ++ T, <<"/">>, N + 1);
                _ ->
                    error
            end;
        {ok, _} ->
            walk(T, Next, N);
        _ ->
            error
    end.

%% ═══ the content hash ════════════════════════════════════════════════════════
%% SHA-256, lowercase hex, streamed: the digest of a 200 MB file costs 64 KiB of
%% heap at a time. Cached by `{Path, Size, Mtime}` only once the file is two
%% seconds old: a file rewritten within the same second at the same size would
%% otherwise keep its old ETag, and a wrong validator is a stale page served
%% with a 304.
hash_file(Path0) ->
    Path = to_bin(Path0),
    fs(),
    case file:read_file_info(Path, [{time, posix}]) of
        {ok, #file_info{size = Size, mtime = Mtime}} ->
            Key = {Path, Size, Mtime},
            case ets:lookup(?HASHES, Key) of
                [{_, Hex}] ->
                    Hex;
                [] ->
                    Hex = digest(Path),
                    case Mtime < erlang:system_time(second) - 2 of
                        true -> true = ets:insert(?HASHES, {Key, Hex});
                        false -> ok
                    end,
                    Hex
            end;
        _ ->
            <<>>
    end.

digest(Path) ->
    fs(),
    case file:open(Path, [raw, read, binary]) of
        {ok, Fd} ->
            Hex = digest_loop(Fd, crypto:hash_init(sha256)),
            _ = file:close(Fd),
            Hex;
        _ ->
            <<>>
    end.

digest_loop(Fd, Ctx) ->
    case file:read(Fd, ?CHUNK) of
        {ok, Data} -> digest_loop(Fd, crypto:hash_update(Ctx, Data));
        eof -> binary:encode_hex(crypto:hash_final(Ctx), lowercase);
        _ -> <<>>
    end.

%% ═══ dates (IMF-fixdate, RFC 9110 § 5.6.7) ═══════════════════════════════════

http_date(Secs) ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:system_time_to_universal_time(Secs, second),
    Dow = element(calendar:day_of_the_week({Y, Mo, D}),
                  {<<"Mon">>, <<"Tue">>, <<"Wed">>, <<"Thu">>, <<"Fri">>, <<"Sat">>, <<"Sun">>}),
    iolist_to_binary(io_lib:format("~s, ~2..0w ~s ~4..0w ~2..0w:~2..0w:~2..0w GMT",
                                   [Dow, D, month_name(Mo), Y, H, Mi, S])).

%% The seconds an IMF-fixdate names, or -1 for anything else — a validator the
%% server cannot read is ignored, never guessed at.
parse_http_date(Raw) ->
    try
        [_Dow, D, Mon, Y, Time, <<"GMT">>] =
            binary:split(string:trim(to_bin(Raw)), [<<" ">>, <<", ">>], [global, trim_all]),
        [H, Mi, S] = binary:split(Time, <<":">>, [global]),
        Mo = month_number(Mon),
        Date = {binary_to_integer(Y), Mo, binary_to_integer(D)},
        true = calendar:valid_date(Date),
        Greg = calendar:datetime_to_gregorian_seconds(
                 {Date, {binary_to_integer(H), binary_to_integer(Mi), binary_to_integer(S)}}),
        Greg - 62167219200
    catch
        _:_ -> -1
    end.

month_name(M) ->
    element(M, {<<"Jan">>, <<"Feb">>, <<"Mar">>, <<"Apr">>, <<"May">>, <<"Jun">>,
                <<"Jul">>, <<"Aug">>, <<"Sep">>, <<"Oct">>, <<"Nov">>, <<"Dec">>}).

month_number(Name) ->
    Names = [<<"Jan">>, <<"Feb">>, <<"Mar">>, <<"Apr">>, <<"May">>, <<"Jun">>,
             <<"Jul">>, <<"Aug">>, <<"Sep">>, <<"Oct">>, <<"Nov">>, <<"Dec">>],
    length(lists:takewhile(fun(N) -> N =/= Name end, Names)) + 1.

%% ═══ the wire ════════════════════════════════════════════════════════════════

has_socket() ->
    get(rakun_conn_socket) =/= undefined.

%% The head (status, queued reply headers, `Content-Length: Length`), then —
%% when `WithBody` (false for HEAD) — `Length` bytes of `Path` from `Offset`.
%% Answers 0, -1 with no connection socket (an in-process call), -2 when the
%% socket refused the bytes.
send_file(Status, Path, Offset, Length, WithBody) ->
    case get(rakun_conn_socket) of
        undefined ->
            -1;
        Sock ->
            case send(Sock, head(Status, Length)) of
                ok ->
                    put(rakun_streamed, true),
                    case WithBody =:= true andalso Length > 0 of
                        true -> body(Sock, to_bin(Path), Offset, Length);
                        false -> 0
                    end;
                _ ->
                    put(rakun_streamed, true),
                    -2
            end
    end.

%% A head with no body: 304 (`Length` < 0 — no `Content-Length` at all, because
%% the only one a 304 may carry is the 200's, RFC 9110 § 15.4.5) and 416
%% (`Length` 0).
send_head(Status, Length) ->
    case get(rakun_conn_socket) of
        undefined ->
            -1;
        Sock ->
            R = send(Sock, head(Status, Length)),
            put(rakun_streamed, true),
            case R of ok -> 0; _ -> -2 end
    end.

head(Status, Length) ->
    Queued = case get(rakun_reply_headers) of
                 undefined -> [];
                 List -> List
             end,
    Lines = [[N, <<": ">>, V, <<"\r\n">>] || {_K, N, V} <- Queued],
    Len = case Length < 0 of
              true -> [];
              false -> [<<"Content-Length: ">>, integer_to_binary(Length), <<"\r\n">>]
          end,
    [<<"HTTP/1.1 ">>, integer_to_binary(Status), <<" ">>, reason(Status), <<"\r\n">>,
     Lines, Len, <<"Connection: keep-alive\r\n\r\n">>].

body(Sock, Path, Offset, Length) ->
    fs(),
    case file:open(Path, [raw, read, binary]) of
        {ok, Fd} ->
            R = case get(rakun_transport) of
                    ssl -> pread_loop(Sock, Fd, Offset, Length);
                    _ ->
                        fs(),
                        case file:sendfile(Fd, Sock, Offset, Length, []) of
                            {ok, _} -> 0;
                            _ -> -2
                        end
                end,
            _ = file:close(Fd),
            R;
        _ ->
            -2
    end.

%% TLS has no zero-copy path: the bytes must be encrypted in the VM. They cross
%% it 64 KiB at a time and are garbage the moment they are sent.
pread_loop(_Sock, _Fd, _Pos, 0) ->
    0;
pread_loop(Sock, Fd, Pos, Left) ->
    fs(),
    case file:pread(Fd, Pos, min(Left, ?CHUNK)) of
        {ok, Data} ->
            case send(Sock, Data) of
                ok -> pread_loop(Sock, Fd, Pos + byte_size(Data), Left - byte_size(Data));
                _ -> -2
            end;
        _ ->
            -2
    end.

send(Sock, Data) ->
    rakun_runtime:t_send(Sock, Data).

reason(200) -> <<"OK">>;
reason(206) -> <<"Partial Content">>;
reason(304) -> <<"Not Modified">>;
reason(416) -> <<"Range Not Satisfiable">>;
reason(_) -> <<"OK">>.

to_bin(B) when is_binary(B) -> B;
to_bin(L) when is_list(L) -> unicode:characters_to_binary(L);
to_bin(A) when is_atom(A) -> atom_to_binary(A, utf8).
