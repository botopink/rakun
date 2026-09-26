%%% rakun-app — metadata file routes, the BEAM half of front 66.
%%%
%%% Only the BYTES: botopink has no byte type, so a static icon or image is read
%%% and hashed here and handed to the handler as an opaque binary it writes
%%% unchanged (a botopink string is a binary on this backend). Everything else
%%% — the registrations, the XML, the robots text, the manifest JSON, the
%%% resolution rule — is botopink.
%%%
%%% MODULE ATOM. `rakun_metadata_routes`, never `metadata_routes`.
-module(rakun_metadata_routes).
-export([read/1, hash/1, hash_text/1, exists/1]).

read(Path) ->
    case file:read_file(Path) of
        {ok, Bin} -> Bin;
        {error, R} -> erlang:error({rakun_metadata, iolist_to_binary(io_lib:format("cannot read ~s: ~p", [Path, R]))})
    end.

%% The first 16 hex characters of the SHA-256 of a file's bytes.
hash(Path) -> hash_text(read(Path)).

hash_text(Bin) ->
    binary:part(string:lowercase(binary:encode_hex(crypto:hash(sha256, Bin))), 0, 16).

exists(Path) -> filelib:is_regular(Path).
