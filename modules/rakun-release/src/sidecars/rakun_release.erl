%%% rakun-release — the host half of front 81: erlang term rendering, a
%%% deterministic tar writer, deterministic beam compilation, tree hashes and
%%% the module facts an upgrade plan classifies by.
%%%
%%% DETERMINISM: every tar entry has mtime 0, uid/gid 0, fixed modes, and
%%% entries are sorted by path; beams are compiled with `deterministic`. Two
%%% builds of the same inputs are the same bytes wherever they run.

-module(rakun_release).
-export([term/1, consult/1, tar/2, compile_dir/1, tree_hash/1, list_files/1,
         module_facts/1, read/1, write/2, exists/1]).

%% `Props` (`[{Key, Value}]` binaries) as the text of `sys.config`.
term(Props) ->
    Config = [{rakun, [{properties, [{K, V} || {K, V} <- Props]}]}],
    unicode:characters_to_binary(io_lib:format("~tp.~n", [Config])).

%% The properties back out of a `sys.config` text, as `[{K, V}]`.
consult(Text) ->
    {ok, Toks, _} = erl_scan:string(unicode:characters_to_list(Text)),
    {ok, Term} = erl_parse:parse_term(Toks),
    [{rakun, [{properties, Props}]}] = Term,
    Props.

%% ═══ the tar writer (POSIX ustar) ════════════════════════════════════════════

%% `Entries` is `[{Path, Bytes}]`; a path under `bin/` is executable.
tar(OutFile, Entries) ->
    Sorted = lists:keysort(1, Entries),
    Body = [entry(P, B) || {P, B} <- Sorted],
    Bin = iolist_to_binary([Body, binary:copy(<<0>>, 1024)]),
    ok = filelib:ensure_dir(OutFile),
    ok = file:write_file(OutFile, Bin),
    byte_size(Bin).

entry(Path, Bytes) ->
    Mode = case binary:match(Path, <<"bin/">>) of {0, _} -> 8#755; _ -> 8#644 end,
    Size = byte_size(Bytes),
    {Name, Prefix} = split_name(Path),
    Header0 = iolist_to_binary([pad(Name, 100), octal(Mode, 8), octal(0, 8), octal(0, 8), octal(Size, 12),
                                octal(0, 12), <<"        ">>, <<"0">>, pad(<<>>, 100), <<"ustar", 0>>, <<"00">>,
                                pad(<<>>, 32), pad(<<>>, 32), octal(0, 8), octal(0, 8), pad(Prefix, 155), pad(<<>>, 12)]),
    Sum = lists:sum(binary_to_list(Header0)),
    <<Before:148/binary, _:8/binary, After/binary>> = Header0,
    Header = <<Before/binary, (checksum(Sum))/binary, After/binary>>,
    Padding = (512 - (Size rem 512)) rem 512,
    [Header, Bytes, binary:copy(<<0>>, Padding)].

split_name(Path) when byte_size(Path) =< 100 -> {Path, <<>>};
split_name(Path) ->
    Parts = binary:split(Path, <<"/">>, [global]),
    split_at(Parts, length(Parts) - 1).

split_at(Parts, N) ->
    {Pre, Post} = lists:split(N, Parts),
    Name = iolist_to_binary(lists:join(<<"/">>, Post)),
    case byte_size(Name) =< 100 of
        true -> {Name, iolist_to_binary(lists:join(<<"/">>, Pre))};
        false -> split_at(Parts, N + 1)
    end.

pad(B, N) -> <<B/binary, (binary:copy(<<0>>, N - byte_size(B)))/binary>>.

octal(V, Width) ->
    S = integer_to_list(V, 8),
    Z = lists:duplicate(Width - 1 - length(S), $0),
    list_to_binary(Z ++ S ++ [0]).

checksum(Sum) ->
    S = integer_to_list(Sum, 8),
    list_to_binary(lists:duplicate(6 - length(S), $0) ++ S ++ [0, $\s]).

%% ═══ beams, files, hashes ════════════════════════════════════════════════════

%% `[{<module>.beam, Bytes}]` for every `.erl` under `Dir`, compiled
%% deterministically; a file that does not compile raises naming it.
compile_dir(Dir) ->
    Files = lists:sort(filelib:wildcard(filename:join([binary_to_list(Dir), "**", "*.erl"]))),
    [case compile:file(F, [binary, deterministic, return_errors]) of
         {ok, Mod, Bin} -> {<<(atom_to_binary(Mod))/binary, ".beam">>, Bin};
         _ -> erlang:error({panic, iolist_to_binary(["rakun release: ", F, " does not compile"])})
     end || F <- Files].

list_files(Dir) ->
    D = binary_to_list(Dir),
    N = length(D) + 1,
    lists:sort([list_to_binary(lists:nthtail(N, F)) || F <- filelib:wildcard(filename:join([D, "**", "*"])), filelib:is_regular(F)]).

%% SHA-256 over the sorted relative paths and contents of `Dir`, excluding
%% `.botopinkbuild/`; `""` for a directory that does not exist.
tree_hash(Dir) ->
    case filelib:is_dir(Dir) of
        false -> <<>>;
        true ->
            Files = [F || F <- list_files(Dir), binary:match(F, <<".botopinkbuild">>) =:= nomatch],
            Ctx = lists:foldl(fun(F, C) ->
                                      {ok, B} = file:read_file(filename:join(binary_to_list(Dir), binary_to_list(F))),
                                      crypto:hash_update(crypto:hash_update(C, F), B)
                              end, crypto:hash_init(sha256), Files),
            binary:encode_hex(crypto:hash_final(Ctx), lowercase)
    end.

%% `behaviours|state-record-fields|exports` of an `.erl` file.
module_facts(File) ->
    {ok, Forms} = epp:parse_file(binary_to_list(File), []),
    Behaviours = [atom_to_binary(B) || {attribute, _, A, B} <- Forms, A =:= behaviour orelse A =:= behavior],
    State = [iolist_to_binary(lists:join(<<",">>, [field(F) || F <- Fs])) || {attribute, _, record, {state, Fs}} <- Forms],
    Exports = [iolist_to_binary([atom_to_binary(F), "/", integer_to_binary(Ar)]) || {attribute, _, export, Es} <- Forms, {F, Ar} <- Es],
    iolist_to_binary([lists:join(<<",">>, Behaviours), "|", case State of [S | _] -> S; [] -> <<>> end, "|",
                      lists:join(<<",">>, Exports)]).

field({record_field, _, {atom, _, N}}) -> atom_to_binary(N);
field({record_field, _, {atom, _, N}, _}) -> atom_to_binary(N);
field({typed_record_field, F, _}) -> field(F);
field(_) -> <<"?">>.

read(File) ->
    case file:read_file(File) of
        {ok, B} -> B;
        _ -> <<>>
    end.

write(File, Bytes) ->
    ok = filelib:ensure_dir(File),
    ok = file:write_file(File, Bytes),
    0.

exists(Path) -> filelib:is_dir(Path) orelse filelib:is_regular(Path).
