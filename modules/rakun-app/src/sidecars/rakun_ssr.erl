%%% rakun — the page path's BEAM half (front 23): the chunk writer.
%%%
%%% WHAT LIVES HERE AND WHY. A page renderer the orchestrator registers writes its status,
%%% its headers and its chunks through a `ChunkWriter` (`ssr.bp`); this module
%%% is what those four functions reach. It never builds a byte of a body: a
%%% chunk goes to the socket as it was handed over, or — when the request came
%%% in without a socket (`rkDispatchHttp` from a test) — into a buffer the
%%% dispatch answers as one `Response`. The node twin `src/ssr.mjs` left with
%%% front 04 Step 10, and the HTML render left for the HTML library (its front 30)
%%% (decision 113): rakun builds no HTML.
%%%
%%% THE STATE IS THE SERVING PROCESS'S. rakun serves each request in its own
%%% process, so the writer's state — status, headers, started, closed, the
%%% buffer — is that process's dictionary, reset by `begin/0` at the start of
%%% every page dispatch. Two requests in flight cannot see one another's writer.
%%%
%%% ON THE SOCKET. The connection process of front 04's listener records its
%%% socket (`rakun_conn_socket`) before it runs the handler. The first `write/1`
%%% (or a `close/0` with nothing written) sends the head — status, the headers
%%% the renderer set over the defaults, the response headers other entries
%%% queued, and `Transfer-Encoding: chunked` (or `Content-Length: 0`) — and
%%% marks the request `rakun_streamed`, which tells the acceptor not to write a
%%% second response. Every chunk after it is one HTTP/1.1 chunk, written as it
%%% is handed over, so the first chunk is on the wire before the last is made.
%%%
%%% MODULE ATOM. `src/sidecars/rakun_ssr.erl`, never `src/ssr.erl`:
%%% `shipErlSidecars` skips a qualifier atom matching an emitted module, and the
%%% skip is silent.
-module(rakun_ssr).

-export([begin_page/0, begin_handler/0, add_header/2, stream/1,
         set_status/1, set_header/2, write/1, close/0,
         status/0, header/1, closed/0, started/0, streamed/0, body/0, guard/1,
         log_failure/1,
         page_request/2, set_fallback/1, clear_fallback/0]).

-define(STATE, rakun_ssr_writer).

%% ═══ the writer ══════════════════════════════════════════════════════════════

begin_page() ->
    put(?STATE, #{status => 200, headers => [], started => false,
                  closed => false, buffer => [], defaults => true}),
    0.

%% A route handler's response (front 25) carries its own headers: no default
%% `Content-Type` is added (a 204 has none), and a header name may repeat.
begin_handler() ->
    _ = begin_page(),
    put(?STATE, (get(?STATE))#{defaults := false}),
    0.

add_header(Name, Value) ->
    S = state(),
    case S of
        #{closed := true} -> refuse(<<"setHeader">>, <<"after close">>);
        #{started := true} -> refuse(<<"setHeader">>, <<"after the first write - the headers are already on the wire">>);
        #{headers := Hs} ->
            put(?STATE, S#{headers := Hs ++ [{string:lowercase(Name), Name, Value}]}),
            ok
    end.

%% Front 25's `streamed`: every thunk is SPAWNED at once (an `@Task` is eager on
%% the BEAM, so only an unstarted thunk can run concurrently), and each result is
%% written as a chunk IN INDEX ORDER as soon as it and every earlier one are in.
%% A thunk that raises ends the stream: the chunks already written stand and the
%% response is closed; the status cannot change after the first chunk. Answers
%% how many chunks were written.
stream(Thunks) ->
    Me = self(),
    Ref = make_ref(),
    Indexed = lists:zip(lists:seq(1, length(Thunks)), Thunks),
    [spawn(fun() ->
               Me ! {Ref, I, try {ok, T()} catch C:E -> {crash, C, E} end}
           end) || {I, T} <- Indexed],
    stream_collect(Ref, 1, length(Thunks), 0).

stream_collect(_Ref, I, N, Written) when I > N ->
    Written;
stream_collect(Ref, I, N, Written) ->
    receive
        {Ref, I, {ok, Chunk}} ->
            ok = write(Chunk),
            stream_collect(Ref, I + 1, N, Written + 1);
        {Ref, I, {crash, _C, _E}} ->
            Written
    end.

state() ->
    case get(?STATE) of
        undefined -> _ = begin_page(), get(?STATE);
        S -> S
    end.

refuse(Call, Why) ->
    erlang:error({rakun_chunk_writer,
                  iolist_to_binary([<<"rakun: ChunkWriter.">>, Call, <<" ">>, Why])}).

set_status(Code) ->
    S = state(),
    case S of
        #{closed := true} -> refuse(<<"setStatus">>, <<"after close">>);
        #{started := true} -> refuse(<<"setStatus">>, <<"after the first write - the status is already on the wire">>);
        _ -> put(?STATE, S#{status := Code}), ok
    end.

set_header(Name, Value) ->
    S = state(),
    case S of
        #{closed := true} -> refuse(<<"setHeader">>, <<"after close">>);
        #{started := true} -> refuse(<<"setHeader">>, <<"after the first write - the headers are already on the wire">>);
        #{headers := Hs} ->
            Key = string:lowercase(Name),
            Kept = [H || {K, _, _} = H <- Hs, K =/= Key],
            put(?STATE, S#{headers := Kept ++ [{Key, Name, Value}]}),
            ok
    end.

write(Chunk) ->
    S = state(),
    case S of
        #{closed := true} -> refuse(<<"write">>, <<"after close">>);
        _ ->
            S1 = case maps:get(started, S) of
                     true -> S;
                     false -> start(S, chunked)
                 end,
            case socket() of
                none ->
                    put(?STATE, S1#{buffer := [Chunk | maps:get(buffer, S1)]});
                Sock ->
                    put(?STATE, S1),
                    Size = integer_to_binary(byte_size(Chunk), 16),
                    _ = send(Sock, [Size, <<"\r\n">>, Chunk, <<"\r\n">>])
            end,
            ok
    end.

close() ->
    S = state(),
    case S of
        #{closed := true} -> refuse(<<"close">>, <<"after close">>);
        #{started := false} ->
            S1 = start(S, empty),
            put(?STATE, S1#{closed := true}),
            ok;
        _ ->
            case socket() of
                none -> ok;
                Sock -> _ = send(Sock, <<"0\r\n\r\n">>)
            end,
            put(?STATE, S#{closed := true}),
            ok
    end.

%% The head goes out with the first chunk, or with `close` when nothing was
%% written — which is how a renderer answers a 307 with `location` and no body.
start(S = #{status := Status, headers := Hs}, Framing) ->
    case socket() of
        none -> ok;
        Sock ->
            Defaults = case maps:get(defaults, S, true) of
                           true -> [{<<"content-type">>, <<"Content-Type">>, <<"text/html; charset=utf-8">>}];
                           false -> []
                       end,
            Own = [K || {K, _, _} <- Hs],
            Merged = [D || {K, _, _} = D <- Defaults, not lists:member(K, Own)] ++ Hs,
            Queued = queued_headers(Own),
            Frame = case Framing of
                        chunked -> <<"Transfer-Encoding: chunked\r\n">>;
                        empty -> <<"Content-Length: 0\r\n">>
                    end,
            Lines = [[N, <<": ">>, V, <<"\r\n">>] || {_, N, V} <- Merged ++ Queued],
            _ = send(Sock, [<<"HTTP/1.1 ">>, integer_to_binary(Status), <<" ">>, reason(Status),
                            <<"\r\n">>, Lines, Frame, <<"Connection: keep-alive\r\n\r\n">>]),
            put(rakun_streamed, true)
    end,
    S#{started := true}.

%% Response headers another entry queued for this request (rakun-web's
%% `withHeader` mirrors into front 04's accumulator), minus any the renderer set.
queued_headers(Own) ->
    case get(rakun_reply_headers) of
        undefined -> [];
        List -> [{K, N, V} || {K, N, V} <- List, not lists:member(K, Own)]
    end.

socket() ->
    case get(rakun_conn_socket) of
        undefined -> none;
        Sock -> Sock
    end.

send(Sock, Data) ->
    rakun_runtime:t_send(Sock, Data).

reason(200) -> <<"OK">>;
reason(201) -> <<"Created">>;
reason(204) -> <<"No Content">>;
reason(301) -> <<"Moved Permanently">>;
reason(302) -> <<"Found">>;
reason(303) -> <<"See Other">>;
reason(307) -> <<"Temporary Redirect">>;
reason(308) -> <<"Permanent Redirect">>;
reason(400) -> <<"Bad Request">>;
reason(405) -> <<"Method Not Allowed">>;
reason(415) -> <<"Unsupported Media Type">>;
reason(404) -> <<"Not Found">>;
reason(500) -> <<"Internal Server Error">>;
reason(_) -> <<"OK">>.

%% ═══ what the dispatch reads back ════════════════════════════════════════════

status() -> maps:get(status, state()).

header(Name) ->
    Key = string:lowercase(Name),
    case [V || {K, _, V} <- maps:get(headers, state()), K =:= Key] of
        [V | _] -> V;
        [] -> <<>>
    end.

closed() -> maps:get(closed, state()).

started() -> maps:get(started, state()).

streamed() -> get(rakun_streamed) =:= true.

body() -> iolist_to_binary(lists:reverse(maps:get(buffer, state()))).

%% Run the renderer; answer the text it answers (`<<>>` when it succeeded, the
%% problem naming its `Error(msg)` otherwise), or the reason it raised. A raise
%% is a failed render — a `nav:` reason included, because page signals are the
%% HTML library's (decision 117 rule 1) and rakun translates none of them.
guard(Thunk) ->
    try Thunk() of
        Text when is_binary(Text) -> Text;
        _ -> <<>>
    catch
        error:{rakun_chunk_writer, Why} -> Why;
        Class:Reason -> iolist_to_binary(io_lib:format("~p:~0p", [Class, Reason]))
    end.

%% A failed render's reason goes to the log, never on the wire (decision 130):
%% one `logger` error under a correlation digest, which is answered.
log_failure(Reason) ->
    Digest = list_to_binary(string:to_lower(integer_to_list(erlang:phash2({Reason, erlang:unique_integer()}), 16))),
    logger:error("rakun ssr: failed render (correlation ~s): ~ts", [Digest, Reason]),
    Digest.

%% ═══ the request a renderer is handed ════════════════════════════════════════
%% The core's request value carries the path parameters the CORE router bound —
%% none, on the page path. This one carries the page pattern's parameters
%% (`name\tvalue` lines) and marks the render dynamic on a query read
%% (front 62's `markDynamic("searchParams")`, which raises under `strict`).
page_request(Req, ParamsWire) ->
    Params = maps:from_list([list_to_tuple(binary:split(L, <<"\t">>))
                             || L <- binary:split(ParamsWire, <<"\n">>, [global]), L =/= <<>>,
                                length(binary:split(L, <<"\t">>)) =:= 2]),
    Query = maps:get(query, Req),
    Req#{params => Params,
         param => fun(_Self, N) ->
                          case maps:find(N, Params) of
                              {ok, V} -> V;
                              error -> <<>>
                          end
                  end,
         query => fun(Self, N) ->
                          _ = 'rakun@request_context':markDynamic(<<"searchParams">>),
                          Query(Self, N)
                  end}.

%% ═══ the page path as the core router's fallback ═════════════════════════════

set_fallback(Fun) ->
    rakun_runtime:set_fallback(Fun).

clear_fallback() ->
    rakun_runtime:clear_fallback().
