%%% rakun-web — the filter chain, BEAM half: the erlang twin of `src/chain.mjs`.
%%%
%%% WHAT LIVES HERE AND WHY. botopink has no top-level mutable state, so the
%%% chain's registries live in the host: the ordered entry table, the advice
%%% table, the per-controller CORS mappings, and the four per-request
%%% accumulators (reply headers, `Set-Cookie` lines, the rewrite signal, the
%%% problem log). An entry is a FUNCTION and no string store holds one, which is
%%% front 22's test for shipping a host file rather than writing over `std`.
%%%
%%% WHAT DOES *NOT* LIVE HERE. The order band, the sentinel interpretation, the
%%% replace-by-name rule, the `Vary` union, the `Set-Cookie` refusal, the CORS
%%% decision, the RFC 9457 shape and every refusal message are botopink,
%%% compiled to both targets. This module holds tables, a walk by index and a
%%% try/catch. It never parses a header and never decides what a policy allows —
%%% which is what makes "the two rows cannot disagree about what the chain did"
%%% a property rather than a hope.
%%%
%%% MODULE ATOM. `src/sidecars/rakun_chain.erl`, never `src/chain.erl`:
%%% `shipErlSidecars` skips any qualifier atom matching a module the build
%%% emitted, rakun-web emits `chain`, and the skip is SILENT. Every rakun
%%% sidecar is `rakun_<name>.erl`.
%%%
%%% TABLE OWNERSHIP. An ETS table dies with the process that created it, and a
%%% registration runs in whatever process loaded the module. So the tables are
%%% created by a dedicated owner process that does nothing but stay alive —
%%% registered under a name, so a second caller losing the race finds the tables
%%% already there rather than making a second set. This is
%%% `rakun_file_router`'s shape and it is here for the same reason.
%%%
%%% WHAT IS PER-REQUEST AND WHY IT IS THE PROCESS DICTIONARY. A request is a
%%% process on the BEAM, so the reply headers, the queued cookie lines, the
%%% rewrite signal and the terminal closure are process-local: a request that
%%% sets none pays nothing and two requests never see each other's.
-module(rakun_chain).

%% the chain registry
-export([register/3, count/0, names/0, orders/0, invoke/3, reset/0]).
%% the terminal
-export([set_terminal/1, terminal/5, has_terminal/0]).
%% the per-request signal
-export([signal/1, put_signal/2, clear_signals/0]).
%% reply headers (write-through to front 04's accumulator)
-export([header_set/2, header_get/1, header_names/0, header_lines/0,
         header_clear/0]).
%% Set-Cookie lines
-export([cookie_add/1, cookie_lines/0, cookie_clear/0]).
%% controller advice
-export([advice_register/3, advice_owner/1, advice_invoke/2, advice_tags/0,
         advice_reset/0]).
%% per-controller CORS mappings
-export([cors_register/3, cors_rows/0, cors_reset/0]).
%% raises and the guard
-export([raise_problem/2, run_guarded/2, problem_log/0, problem_log_reset/0,
         problem_digest/1, problem_note/1, fresh_id/0]).
%% the boot-time key/value table
-export([meta_put/2, meta_get/1, meta_reset/0]).
%% the ordering trace
-export([trace/1, trace_log/0, trace_reset/0]).
%% the seam front 04's `dispatch_http/5` calls
-export([run/6, set_runner/1]).

%% reachable for a test or a later front
-export([ensure/0, owner/1]).

-define(ENTRIES, rakun_web_entries).   %% ordered_set: {{Order, Seq}, Name, Entry}
-define(SEQ, rakun_web_seq).           %% set:         {Key, Integer}
-define(ADVICE, rakun_web_advice).     %% ordered_set: {Seq, Tag, Owner, Handler}
-define(CORS, rakun_web_cors).         %% ordered_set: {Seq, Prefix, Origins, Methods}
-define(LOG, rakun_web_log).           %% ordered_set: {Seq, Line}
-define(RUNNER, rakun_web_runner).     %% set:         {runner, Fun}
-define(META, rakun_web_meta).         %% set:         {Key, Value}
-define(TRACE, rakun_web_trace).       %% ordered_set: {Seq, Line}
-define(OWNER, rakun_web_owner).

-define(HEADERS, rakun_web_headers).   %% process dict: [{LowerName, Name, Value}]
-define(COOKIES, rakun_web_cookies).   %% process dict: [Line]
-define(SIGNALS, rakun_web_signals).   %% process dict: [{Key, Value}]
-define(TERMINAL, rakun_web_terminal). %% process dict: fun/5

%% ═══ lifecycle ═══════════════════════════════════════════════════════════════

ensure() ->
    case ets:whereis(?ENTRIES) of
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
            Common = [named_table, public, {read_concurrency, true}],
            _ = ets:new(?ENTRIES, [ordered_set | Common]),
            _ = ets:new(?SEQ, [set | Common]),
            _ = ets:new(?ADVICE, [ordered_set | Common]),
            _ = ets:new(?CORS, [ordered_set | Common]),
            _ = ets:new(?LOG, [ordered_set | Common]),
            _ = ets:new(?RUNNER, [set | Common]),
            _ = ets:new(?META, [set | Common]),
            _ = ets:new(?TRACE, [ordered_set | Common]),
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

%% ═══ the chain registry ══════════════════════════════════════════════════════
%% Keyed `{Order, Seq}` on an ordered_set, so the table is WALKED rather than
%% sorted per request and two entries at the same order break the tie by
%% registration order.

register(Name, Order, Entry) ->
    ensure(),
    Seq = next_seq(entries),
    true = ets:insert(?ENTRIES, {{Order, Seq}, Name, Entry}),
    Seq.

count() ->
    ensure(),
    ets:info(?ENTRIES, size).

names() ->
    ensure(),
    join([N || {_K, N, _E} <- ets:tab2list(?ENTRIES)], <<"\n">>).

orders() ->
    ensure(),
    join([integer_to_binary(O) || {{O, _S}, _N, _E} <- ets:tab2list(?ENTRIES)], <<"\n">>).

invoke(I, Req, Chain) ->
    ensure(),
    {_K, _N, Entry} = lists:nth(I + 1, ets:tab2list(?ENTRIES)),
    Entry(Req, Chain).

reset() ->
    ensure(),
    true = ets:delete_all_objects(?ENTRIES),
    true = ets:delete_all_objects(?SEQ),
    0.

%% ═══ the terminal ════════════════════════════════════════════════════════════
%% What the chain calls when the walk runs past the last entry: the route
%% handler in a real request, a test's own closure in a cell. Per-process,
%% because in a real request it closes over that request's scalars.

set_terminal(Fun) ->
    put(?TERMINAL, Fun),
    0.

has_terminal() ->
    get(?TERMINAL) =/= undefined.

terminal(Method, Path, HeadersWire, QueryWire, Body) ->
    case get(?TERMINAL) of
        undefined -> #{status => 404, body => <<>>};
        Fun -> Fun(Method, Path, HeadersWire, QueryWire, Body)
    end.

%% ═══ the per-request signal ══════════════════════════════════════════════════
%% `rewrite` records the new dispatch path here rather than in a header, so
%% nothing leaks to the client.

signal(Key) ->
    case lists:keyfind(Key, 1, signals()) of
        false -> <<>>;
        {_K, V} -> V
    end.

put_signal(Key, Value) ->
    put(?SIGNALS, lists:keystore(Key, 1, signals(), {Key, Value})),
    0.

clear_signals() ->
    erase(?SIGNALS),
    0.

signals() ->
    case get(?SIGNALS) of
        undefined -> [];
        L -> L
    end.

%% ═══ reply headers ═══════════════════════════════════════════════════════════
%% The accumulator rakun-web composes with, mirrored into front 04's
%% `rakun_runtime:set_reply_header/2` so the lines reach the wire. The mirror is
%% one-way and best effort: a build without the core's sidecar loaded still has
%% a working chain, and `rakun_runtime` is what puts a header on a socket.
%%
%% Replace-by-name, the `Vary` union and the `Set-Cookie` refusal are all in
%% botopink — this module is told the finished value.

header_set(Name, Value) ->
    Key = lower(Name),
    Kept = [H || {K, _N, _V} = H <- header_list(), K =/= Key],
    put(?HEADERS, Kept ++ [{Key, Name, Value}]),
    _ = mirror(Name, Value),
    0.

mirror(Name, Value) ->
    case erlang:function_exported(rakun_runtime, set_reply_header, 2) of
        true -> rakun_runtime:set_reply_header(Name, Value);
        false -> 0
    end.

header_get(Name) ->
    Key = lower(Name),
    case lists:keyfind(Key, 1, header_list()) of
        false -> <<>>;
        {_K, _N, V} -> V
    end.

header_names() ->
    join([K || {K, _N, _V} <- header_list()], <<"\n">>).

header_lines() ->
    join([<<N/binary, ": ", V/binary>> || {_K, N, V} <- header_list()], <<"\n">>).

header_clear() ->
    erase(?HEADERS),
    0.

header_list() ->
    case get(?HEADERS) of
        undefined -> [];
        L -> L
    end.

%% ═══ Set-Cookie ══════════════════════════════════════════════════════════════
%% Never routed through `header_set/2`: a replace would lose every cookie but
%% the last. Front 62's `endRequest` hands the lines as a list and the chain
%% writes them verbatim, one `Set-Cookie:` per element.

cookie_add(Line) ->
    put(?COOKIES, cookie_list() ++ [Line]),
    length(cookie_list()).

cookie_lines() ->
    join(cookie_list(), <<"\n">>).

cookie_clear() ->
    erase(?COOKIES),
    0.

cookie_list() ->
    case get(?COOKIES) of
        undefined -> [];
        L -> L
    end.

%% ═══ controller advice ═══════════════════════════════════════════════════════

advice_register(Tag, Owner, Handler) ->
    ensure(),
    Seq = next_seq(advice),
    true = ets:insert(?ADVICE, {Seq, Tag, Owner, Handler}),
    Seq.

%% The owner recorded for a tag, or `<<>>` — the duplicate refusal names both
%% owners and reads this for the first one.
advice_owner(Tag) ->
    ensure(),
    case [O || {_S, T, O, _H} <- ets:tab2list(?ADVICE), T =:= Tag] of
        [] -> <<>>;
        [First | _] -> First
    end.

advice_invoke(Tag, Detail) ->
    ensure(),
    case [H || {_S, T, _O, H} <- ets:tab2list(?ADVICE), T =:= Tag] of
        [] -> undefined;
        [Handler | _] -> Handler(Detail)
    end.

advice_tags() ->
    ensure(),
    join([T || {_S, T, _O, _H} <- ets:tab2list(?ADVICE)], <<"\n">>).

advice_reset() ->
    ensure(),
    true = ets:delete_all_objects(?ADVICE),
    0.

%% ═══ per-controller CORS mappings ════════════════════════════════════════════

cors_register(Prefix, Origins, Methods) ->
    ensure(),
    Seq = next_seq(cors),
    true = ets:insert(?CORS, {Seq, Prefix, Origins, Methods}),
    Seq.

%% One `prefix\torigins\tmethods` line per mapping, in registration order. The
%% longest-prefix choice is botopink's.
cors_rows() ->
    ensure(),
    join([<<P/binary, "\t", O/binary, "\t", M/binary>>
          || {_S, P, O, M} <- ets:tab2list(?CORS)], <<"\n">>).

cors_reset() ->
    ensure(),
    true = ets:delete_all_objects(?CORS),
    0.

%% ═══ raises and the guard ════════════════════════════════════════════════════
%% botopink has no typed raise and no user-visible catch of one: `throw` is legal
%% only under a `@Result` return and yields an `Error(e)` VALUE. So the raise and the
%% catch are both here, and the error entry hands in two closures.

raise_problem(Tag, Detail) ->
    throw({rakun_problem, Tag, Detail}).

%% `OnProblem(Tag, Detail)` for a tagged raise; for anything else `Tag` is
%% `<<>>` and `Detail` is a DIGEST of the reason, never the reason — the full
%% term goes to the log under that digest and nowhere near a response body.
run_guarded(Work, OnProblem) ->
    ensure(),
    try Work()
    catch
        throw:{rakun_problem, Tag, Detail} -> OnProblem(Tag, Detail);
        error:{rakun_problem, Tag, Detail} -> OnProblem(Tag, Detail);
        Class:Reason:Stack ->
            Digest = digest({Class, Reason}),
            log(<<Digest/binary, " ",
                  (iolist_to_binary(io_lib:format("~p:~p", [Class, Reason])))/binary, " ",
                  (iolist_to_binary(io_lib:format("~p", [Stack])))/binary>>),
            OnProblem(<<>>, Digest)
    end.

digest(Term) ->
    list_to_binary(string:to_lower(integer_to_list(erlang:phash2(Term, 4294967296), 16))).

log(Line) ->
    Seq = next_seq(log),
    true = ets:insert(?LOG, {Seq, Line}),
    0.

problem_log() ->
    ensure(),
    join([L || {_S, L} <- ets:tab2list(?LOG)], <<"\n">>).

problem_log_reset() ->
    ensure(),
    true = ets:delete_all_objects(?LOG),
    0.

%% The same digest the untagged path computes, for a TAGGED raise nothing
%% handled: the correlation id a body may carry, over a term a body may not.
problem_digest(Text) ->
    digest(Text).

problem_note(Line) ->
    ensure(),
    log(Line).

%% A fresh per-request identifier. Not a UUID: there is no `random` cell in this
%% module and the chain's request id is a correlation handle, not a token. It is
%% unique within a node run, which is what a log join needs.
fresh_id() ->
    N = erlang:unique_integer([positive, monotonic]),
    list_to_binary(integer_to_list(N, 16)).

%% ═══ the ordering trace ═════════════════════════════════════════════════════
%% What a filter appends on the way in and on the way out, so a test asserts the
%% WHOLE sequence as one string rather than asserting each filter ran. ETS, not
%% the process dictionary: the trace outlives the request it recorded.

trace(Line) ->
    ensure(),
    Seq = next_seq(trace),
    true = ets:insert(?TRACE, {Seq, Line}),
    0.

trace_log() ->
    ensure(),
    join([L || {_S, L} <- ets:tab2list(?TRACE)], <<"|">>).

trace_reset() ->
    ensure(),
    true = ets:delete_all_objects(?TRACE),
    0.

%% ═══ the boot-time key/value table ══════════════════════════════════════════
%% Registration runs at module load, in whatever process loaded the module, so
%% what a registration records lives in ETS and not in the process dictionary.

meta_put(Key, Value) ->
    ensure(),
    true = ets:insert(?META, {Key, Value}),
    0.

meta_get(Key) ->
    ensure(),
    case ets:lookup(?META, Key) of
        [] -> <<>>;
        [{_K, V}] -> V
    end.

meta_reset() ->
    ensure(),
    true = ets:delete_all_objects(?META),
    0.

%% ═══ the seam ════════════════════════════════════════════════════════════════
%% `rakun_runtime:dispatch_http/5` calls `rakun_chain:run/6` when this module is
%% in the build and the handler directly when it is not. That branch is the
%% entire integration surface — front 07 adds no second hook.
%%
%% The runner is botopink's `runChain/1`, registered at module load, so this
%% module hardcodes no emitted atom.

set_runner(Fun) ->
    ensure(),
    true = ets:insert(?RUNNER, {runner, Fun}),
    0.

run(Verb, Path, HeadersJson, QueryJson, Body, Handler) ->
    ensure(),
    case ets:lookup(?RUNNER, runner) of
        [] ->
            Handler(Verb, Path, HeadersJson, QueryJson, Body, undefined);
        [{runner, Runner}] ->
            _ = header_clear(),
            _ = cookie_clear(),
            _ = clear_signals(),
            %% The terminal ignores the wire forms it is handed and uses the
            %% JSON the dispatcher decoded, so a rewritten PATH re-targets the
            %% route table and nothing else changes.
            _ = set_terminal(fun(M, P, _HW, _QW, B) ->
                                     Handler(M, P, HeadersJson, QueryJson, B, undefined)
                             end),
            Runner(Verb, Path, wire(HeadersJson), wire(QueryJson), Body)
    end.

%% `{"a":"1","b":"2"}` → `a\t1\nb\t2`, names lowercased. The chain's request
%% value reads headers through front 62's wire grammar, which is botopink.
wire(Json) ->
    case decode_object(Json) of
        Map when is_map(Map) ->
            join([<<(lower(K))/binary, "\t", (to_bin(V))/binary>>
                  || {K, V} <- maps:to_list(Map)], <<"\n">>);
        _ -> <<>>
    end.

decode_object(Json) ->
    try json:decode(Json) of
        Map when is_map(Map) -> Map;
        _ -> #{}
    catch _:_ -> #{}
    end.

to_bin(V) when is_binary(V) -> V;
to_bin(V) when is_integer(V) -> integer_to_binary(V);
to_bin(V) when is_list(V) -> iolist_to_binary(V);
to_bin(_) -> <<>>.

%% ═══ helpers ═════════════════════════════════════════════════════════════════

lower(B) when is_binary(B) -> list_to_binary(string:to_lower(binary_to_list(B)));
lower(B) -> B.

join([], _Sep) -> <<>>;
join(List, Sep) -> iolist_to_binary(lists:join(Sep, List)).
