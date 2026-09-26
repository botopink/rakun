%%% rakun-actuator-api — the registries every module writes into, and the span
%%% emitter. Front 11 Step 0.
%%%
%%% WHAT LIVES HERE. Three registries — health indicators, info contributors,
%%% endpoints — plus the one `#[instrumentation]` hook and the span seam. A
%%% registration is a FUNCTION and no string store holds one, which is why this
%%% is a host file at all.
%%%
%%% WHAT DOES *NOT* LIVE HERE. No status order, no timeout, no route, no
%%% exposure, no HTTP mapping, no aggregation: a registration is API, a decision
%%% is host (`modules/rakun-actuator/src/sidecars/rakun_actuator.erl`). The
%%% duplicate-id refusal is botopink (`registration.bp`); this module only
%%% answers who registered an id first.
%%%
%%% TABLE OWNERSHIP. An ETS table dies with the process that created it, and a
%%% registration runs in whatever process loaded the module. So the tables are
%%% created by a dedicated owner process registered as `rakun_actuator_api_owner`
%%% that does nothing but stay alive. The host never owns them, so a host restart
%%% cannot lose a registration. This is `rakun_chain`'s shape.
%%%
%%% SPANS COST NOTHING WITHOUT A SUBSCRIBER. The subscriber list is a
%%% `persistent_term` (read without a copy or a lock), and `:telemetry` is called
%%% only when its module is loaded. With neither, `emit/8` is two lookups and
%%% returns. The per-process span stack is the process dictionary: a request is a
%%% process, so parenting is per request for free.
-module(rakun_actuator_api).

-export([register_health/3, health_owner/1, health_ids/0, health_fun/1, health_remove/1]).
-export([register_info/3, info_owner/1, info_ids/0, info_fun/1, info_remove/1]).
-export([register_endpoint/4, endpoint_owner/1, endpoint_ids/0, endpoint_fun/1,
         endpoint_ops/1, endpoint_remove/1]).
-export([register_instrumentation/2, instrumentation_owner/0, instrumentation_fun/0,
         instrumentation_reset/0]).
-export([table_facts/0]).
-export([fresh_trace_id/0, fresh_span_id/0, now_micros/0,
         span_current/0, span_push/2, span_pop/1, span_clear/0,
         emit/8, emit_start/5, emit_stop/7, subscribe/1, subscriber_count/0, unsubscribe_all/0,
         span_log_enable/0, span_log/0, span_log_reset/0]).
-export([ensure/0, owner/1]).

-define(HEALTH, rakun_actuator_health).     %% set: {Id, Owner, Fun}
-define(INFO, rakun_actuator_info).         %% set: {Id, Owner, Fun}
-define(ENDPOINTS, rakun_actuator_endpoints). %% set: {Id, Owner, Ops, Fun}
-define(HOOKS, rakun_actuator_hooks).       %% set: {instrumentation, Owner, Fun}
-define(SPANLOG, rakun_actuator_span_log).  %% ordered_set: {Seq, Line}
-define(OWNER, rakun_actuator_api_owner).
-define(SUBS, rakun_actuator_span_subscribers). %% persistent_term key
-define(STACK, rakun_actuator_span_stack).  %% process dictionary

%% ═══ lifecycle ═══════════════════════════════════════════════════════════════

ensure() ->
    case ets:whereis(?HEALTH) of
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
            _ = ets:new(?HEALTH, [set | Common]),
            _ = ets:new(?INFO, [set | Common]),
            _ = ets:new(?ENDPOINTS, [set | Common]),
            _ = ets:new(?HOOKS, [set | Common]),
            _ = ets:new(?SPANLOG, [ordered_set | Common]),
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

%% ═══ the health registry ═════════════════════════════════════════════════════

register_health(Id, Owner, Fun) ->
    ensure(),
    true = ets:insert(?HEALTH, {Id, Owner, Fun}),
    0.

health_owner(Id) ->
    ensure(),
    case ets:lookup(?HEALTH, Id) of
        [{_, Owner, _}] -> Owner;
        [] -> <<>>
    end.

health_ids() ->
    ensure(),
    join(lists:sort([Id || {Id, _, _} <- ets:tab2list(?HEALTH)]), <<"\n">>).

health_fun(Id) ->
    ensure(),
    case ets:lookup(?HEALTH, Id) of
        [{_, _, Fun}] -> Fun;
        [] -> undefined
    end.

health_remove(Id) ->
    ensure(),
    true = ets:delete(?HEALTH, Id),
    0.

%% ═══ the info registry ═══════════════════════════════════════════════════════

register_info(Id, Owner, Fun) ->
    ensure(),
    true = ets:insert(?INFO, {Id, Owner, Fun}),
    0.

info_owner(Id) ->
    ensure(),
    case ets:lookup(?INFO, Id) of
        [{_, Owner, _}] -> Owner;
        [] -> <<>>
    end.

info_ids() ->
    ensure(),
    join(lists:sort([Id || {Id, _, _} <- ets:tab2list(?INFO)]), <<"\n">>).

info_fun(Id) ->
    ensure(),
    case ets:lookup(?INFO, Id) of
        [{_, _, Fun}] -> Fun;
        [] -> undefined
    end.

info_remove(Id) ->
    ensure(),
    true = ets:delete(?INFO, Id),
    0.

%% ═══ the endpoint registry ═══════════════════════════════════════════════════

register_endpoint(Id, Owner, Ops, Fun) ->
    ensure(),
    true = ets:insert(?ENDPOINTS, {Id, Owner, Ops, Fun}),
    0.

endpoint_owner(Id) ->
    ensure(),
    case ets:lookup(?ENDPOINTS, Id) of
        [{_, Owner, _, _}] -> Owner;
        [] -> <<>>
    end.

endpoint_ids() ->
    ensure(),
    join(lists:sort([Id || {Id, _, _, _} <- ets:tab2list(?ENDPOINTS)]), <<"\n">>).

endpoint_fun(Id) ->
    ensure(),
    case ets:lookup(?ENDPOINTS, Id) of
        [{_, _, _, Fun}] -> Fun;
        [] -> undefined
    end.

endpoint_ops(Id) ->
    ensure(),
    case ets:lookup(?ENDPOINTS, Id) of
        [{_, _, Ops, _}] -> Ops;
        [] -> <<>>
    end.

endpoint_remove(Id) ->
    ensure(),
    true = ets:delete(?ENDPOINTS, Id),
    0.

%% ═══ the #[instrumentation] hook ═════════════════════════════════════════════

register_instrumentation(Owner, Fun) ->
    ensure(),
    true = ets:insert(?HOOKS, {instrumentation, Owner, Fun}),
    0.

instrumentation_owner() ->
    ensure(),
    case ets:lookup(?HOOKS, instrumentation) of
        [{_, Owner, _}] -> Owner;
        [] -> <<>>
    end.

instrumentation_fun() ->
    ensure(),
    case ets:lookup(?HOOKS, instrumentation) of
        [{_, _, Fun}] -> Fun;
        [] -> undefined
    end.

instrumentation_reset() ->
    ensure(),
    true = ets:delete(?HOOKS, instrumentation),
    0.

%% ═══ the table facts ═════════════════════════════════════════════════════════
%% `<table> named=<bool> protection=<p> owner=<api|other>` per registry — what
%% the "named_table, public, owned by the API and not the host" box reads.

table_facts() ->
    ensure(),
    OwnerPid = whereis(?OWNER),
    Lines = [begin
                 Named = ets:info(T, named_table),
                 Prot = ets:info(T, protection),
                 Own = case ets:info(T, owner) of OwnerPid -> <<"api">>; _ -> <<"other">> end,
                 iolist_to_binary([atom_to_binary(T), <<" named=">>, atom_to_binary(Named),
                                   <<" protection=">>, atom_to_binary(Prot), <<" owner=">>, Own])
             end || T <- [?HEALTH, ?INFO, ?ENDPOINTS]],
    join(Lines, <<"\n">>).

%% ═══ spans ═══════════════════════════════════════════════════════════════════
%% W3C trace-context ids: a 16-byte trace id and an 8-byte span id, lowercase
%% hex. `rand:bytes/1` rather than `crypto`: a span id is a correlation handle,
%% not a secret, and `crypto` is an application a minimal node may not start.

fresh_trace_id() ->
    hex(nonzero(16)).

fresh_span_id() ->
    hex(nonzero(8)).

nonzero(N) ->
    B = rand:bytes(N),
    case B =:= binary:copy(<<0>>, N) of
        true -> nonzero(N);
        false -> B
    end.

hex(Bin) ->
    << <<(hexdigit(H)), (hexdigit(L))>> || <<H:4, L:4>> <= Bin >>.

hexdigit(D) when D < 10 -> $0 + D;
hexdigit(D) -> $a + D - 10.

now_micros() ->
    erlang:system_time(microsecond).

%% The caller's current span as `trace\tspan`, or `<<>>` outside any span.
span_current() ->
    case get(?STACK) of
        [{T, S} | _] -> <<T/binary, "\t", S/binary>>;
        _ -> <<>>
    end.

span_push(Trace, Span) ->
    Stack = case get(?STACK) of undefined -> []; L -> L end,
    put(?STACK, [{Trace, Span} | Stack]),
    0.

%% Pops down to and including `Span`; a span ended out of order does not leave
%% its children on the stack.
span_pop(Span) ->
    Stack = case get(?STACK) of undefined -> []; L -> L end,
    case lists:keymember(Span, 2, Stack) of
        true -> put(?STACK, drop_to(Span, Stack));
        false -> ok
    end,
    0.

drop_to(_Span, []) -> [];
drop_to(Span, [{_, Span} | Rest]) -> Rest;
drop_to(Span, [_ | Rest]) -> drop_to(Span, Rest).

span_clear() ->
    erase(?STACK),
    0.

%% `Phase` is `start` or `stop`. The `:telemetry` event name is `rakun` then the
%% span name's segments, a trailing `request` dropped, then the phase:
%% `http.server.request` → `[rakun, http, server, stop]`, `render` →
%% `[rakun, render, stop]`.
emit(Phase, Name, Trace, SpanId, Parent, Attributes, DurationMicros, Outcome) ->
    Subs = persistent_term:get(?SUBS, []),
    Tel = erlang:function_exported(telemetry, execute, 3),
    case {Subs, Tel} of
        {[], false} -> 0;
        _ -> deliver(Subs, Tel, Phase, Name, Trace, SpanId, Parent, Attributes,
                     DurationMicros, Outcome)
    end.

emit_start(Name, Trace, SpanId, Parent, Attributes) ->
    emit(<<"start">>, Name, Trace, SpanId, Parent, Attributes, 0, <<>>).

emit_stop(Name, Trace, SpanId, Parent, Attributes, DurationMicros, Outcome) ->
    emit(<<"stop">>, Name, Trace, SpanId, Parent, Attributes, DurationMicros, Outcome).

deliver(Subs, Tel, Phase, Name, Trace, SpanId, Parent, Attributes, Duration, Outcome) ->
    Segs = event_segments(Name),
    EventAtoms = [rakun | [binary_to_atom(S) || S <- Segs]] ++ [binary_to_atom(Phase)],
    EventText = join([<<"rakun">> | Segs] ++ [Phase], <<".">>),
    Measurements = case Phase of
                       <<"stop">> -> #{duration => Duration, system_time => now_micros()};
                       _ -> #{system_time => now_micros()}
                   end,
    Metadata = #{name => Name, trace_id => Trace, span_id => SpanId,
                 parent_id => Parent, attributes => Attributes, outcome => Outcome},
    _ = case Tel of
            true -> catch apply(telemetry, execute, [EventAtoms, Measurements, Metadata]);
            false -> ok
        end,
    MJson = iolist_to_binary(json:encode(Measurements)),
    DJson = iolist_to_binary(json:encode(Metadata)),
    lists:foreach(fun(F) -> catch F(EventText, MJson, DJson) end, Subs),
    0.

event_segments(Name) ->
    Segs = [S || S <- binary:split(Name, <<".">>, [global]), S =/= <<>>],
    case lists:reverse(Segs) of
        [<<"request">> | Rest] when Rest =/= [] -> lists:reverse(Rest);
        _ -> Segs
    end.

subscribe(Fun) ->
    persistent_term:put(?SUBS, persistent_term:get(?SUBS, []) ++ [Fun]),
    length(persistent_term:get(?SUBS)).

subscriber_count() ->
    length(persistent_term:get(?SUBS, [])).

unsubscribe_all() ->
    _ = persistent_term:erase(?SUBS),
    0.

%% The log subscriber: what an application with front 11 alone reads spans in.
%% One line per event: `<event> <name> trace=<t> span=<s> parent=<p> outcome=<o>`.
span_log_enable() ->
    ensure(),
    subscribe(fun(Event, _M, DJson) ->
                      D = json:decode(DJson),
                      Line = iolist_to_binary([Event, <<" ">>, maps:get(<<"name">>, D),
                                               <<" trace=">>, maps:get(<<"trace_id">>, D),
                                               <<" span=">>, maps:get(<<"span_id">>, D),
                                               <<" parent=">>, maps:get(<<"parent_id">>, D),
                                               <<" outcome=">>, maps:get(<<"outcome">>, D)]),
                      Seq = erlang:unique_integer([monotonic, positive]),
                      true = ets:insert(?SPANLOG, {Seq, Line}),
                      0
              end).

span_log() ->
    ensure(),
    join([L || {_, L} <- ets:tab2list(?SPANLOG)], <<"\n">>).

span_log_reset() ->
    ensure(),
    true = ets:delete_all_objects(?SPANLOG),
    0.

%% ═══ helpers ═════════════════════════════════════════════════════════════════

join([], _Sep) -> <<>>;
join(List, Sep) -> iolist_to_binary(lists:join(Sep, List)).
