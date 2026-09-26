%%% rakun — the file-convention route registry, BEAM half: its node twin `src/file_router.mjs` left
%%% with front 04 Step 10 (decision 113).
%%%
%%% WHAT LIVES HERE AND WHY. botopink has no top-level mutable state, so a
%%% registry lives in the host. This one is the App-Router table, filled by the
%%% module-load `val`s the four markers in `file_router.bp` emit, and it holds a
%%% registered render FUNCTION, which no string store can hold.
%%%
%%% WHAT DOES NOT LIVE HERE. The segment grammar, the wire format and the
%%% matcher are botopink, compiled to erlang. This module never parses a
%%% segment and never builds a record: it is handed the finished
%%% `kind|pattern|slot|verb` line and appends it beside its function. Neither
%%% host knows the format, which is what makes "the two sides cannot disagree
%%% about which route a URL is" a property rather than a hope.
%%%
%%% MODULE ATOM. `src/sidecars/rakun_file_router.erl`, never
%%% `src/file_router.erl`: `shipErlSidecars` skips any qualifier atom matching a
%%% module the build emitted, rakun emits `rakun/file_router`, and the skip is
%%% SILENT. Every rakun sidecar is `rakun_<name>.erl`.
%%%
%%% TABLE OWNERSHIP. An ETS table dies with the process that created it, and a
%%% registration runs in whatever process loaded the module. So the table is
%%% created by a dedicated owner process that does nothing but stay alive —
%%% registered under a name, so a second caller losing the race finds the table
%%% already there rather than making a second one. This module deliberately does
%%% NOT reuse `rakun_runtime`'s supervision tree: `shipErlSidecars` ships a
%%% sidecar per atom named in emitted output, the two are shipped independently,
%%% and a file-convention program that never touches the DI container should not
%%% start an application to hold four rows.
-module(rakun_file_router).

-export([register_page/2, register_layout/2, register_template/2,
         register_default/2, register_handler/2,
         register_source/2, sources/0,
         table/0, count/0, has_render/1, render/2, reset/0]).

%% reachable for a test or a later front
-export([ensure/0, owner/1]).

-define(TAB, rakun_app_routes).     %% ordered_set: {Seq, Record, Fun}
-define(SRC, rakun_app_sources).    %% ordered_set: {Seq, Line}
-define(SEQ, rakun_app_routes_seq). %% set:         {seq, Integer}
-define(OWNER, rakun_app_routes_owner).

%% ═══ lifecycle ═══════════════════════════════════════════════════════════════

ensure() ->
    case ets:whereis(?TAB) of
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

%% The owner: create the tables, tell the caller they exist, then stay alive.
%% A second owner that loses `register/2` answers the caller anyway and exits,
%% so nothing waits on a race it lost.
owner(Caller) ->
    case catch erlang:register(?OWNER, self()) of
        true ->
            Common = [named_table, public, {read_concurrency, true}],
            _ = ets:new(?TAB, [ordered_set | Common]),
            _ = ets:new(?SRC, [ordered_set | Common]),
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

next_seq() ->
    ets:update_counter(?SEQ, seq, {2, 1}, {seq, 0}).

%% ═══ the cells of `src/file_router.bp` ═══════════════════════════════════════
%% One cell per convention so the botopink side can type each render function
%% differently; the body is the same append for all five.

register_page(Record, Render) -> add(Record, Render).
register_layout(Record, Render) -> add(Record, Render).
register_template(Record, Render) -> add(Record, Render).
register_default(Record, Render) -> add(Record, Render).
register_handler(Record, Handle) -> add(Record, Handle).

add(Record, Fun) ->
    ensure(),
    Seq = next_seq(),
    true = ets:insert(?TAB, {Seq, Record, Fun}),
    ets:info(?TAB, size).

%% Where each registration was WRITTEN: `seg|fnName`, one per line. The wire
%% record carries the URL pattern, not the app-relative directory, and the scan
%% has to check the DIRECTORY the marker was given against the real tree and
%% name the function that got it wrong.
register_source(Seg, FnName) ->
    ensure(),
    Seq = next_seq(),
    Line = <<(to_bin(Seg))/binary, "|", (to_bin(FnName))/binary>>,
    true = ets:insert(?SRC, {Seq, Line}),
    ets:info(?SRC, size).

sources() ->
    ensure(),
    join([L || {_Seq, L} <- ets:tab2list(?SRC)]).

%% The table, in registration order, `\n`-separated — exactly the blob
%% `parseTable` reads.
table() ->
    ensure(),
    join([R || {_Seq, R, _F} <- ets:tab2list(?TAB)]).

join([]) -> <<>>;
join([H | T]) ->
    lists:foldl(fun(X, Acc) -> <<Acc/binary, "\n", X/binary>> end,
                to_bin(H), [to_bin(X) || X <- T]).

to_bin(B) when is_binary(B) -> B;
to_bin(L) when is_list(L) -> list_to_binary(L).

count() ->
    ensure(),
    ets:info(?TAB, size).

%% Was a function stored beside this record? The claim "the registry holds the
%% renderer" is worth an assertion rather than a comment.
has_render(Record) ->
    ensure(),
    R = to_bin(Record),
    lists:any(fun({_Seq, Rec, Fun}) -> Rec =:= R andalso is_function(Fun) end,
              ets:tab2list(?TAB)).

%% The stored function, or `Fallback` when nothing registered that record.
%% Total and typed — an optional function type is a shape neither row reads
%% comfortably, and front 23 needs a value it can call either way.
render(Record, Fallback) ->
    ensure(),
    R = to_bin(Record),
    case [F || {_Seq, Rec, F} <- ets:tab2list(?TAB),
               Rec =:= R, is_function(F)] of
        [F | _] -> F;
        [] -> Fallback
    end.

%% The table is node-global; a test that wants to assert over a table of its own
%% empties it first.
reset() ->
    ensure(),
    true = ets:delete_all_objects(?TAB),
    true = ets:delete_all_objects(?SRC),
    true = ets:insert(?SEQ, {seq, 0}),
    0.
