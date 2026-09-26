%%% rakun-messaging — the byte half of front 91's Pulsar arm. Botopink has no
%%% byte type and no shift or mask operator, so every piece of the binary
%%% protocol is here: CRC32C (Castagnoli, table-driven — `erlang:crc32` is
%%% CRC-32), protobuf varints and the subset of `BaseCommand` this front
%%% encodes, and the frame envelope:
%%%   [totalSize:32][commandSize:32][BaseCommand]                  (simple)
%%%   … + [0x0e01][crc32c:32][metadataSize:32][metadata][payload]   (payload)
%%% A frame split across reads is reassembled by `decode/2`; one larger than
%%% the maximum is refused naming the limit.

-module(rakun_pulsar).
-export([crc32c/1, varint/1, encode_simple/2, encode_payload/4, decode/2, command_type/1, command_name/1]).

crc_table() ->
    case persistent_term:get(rakun_crc32c_table, undefined) of
        undefined ->
            T = list_to_tuple([crc_entry(N, 8) || N <- lists:seq(0, 255)]),
            persistent_term:put(rakun_crc32c_table, T),
            T;
        T -> T
    end.

crc_entry(C, 0) -> C;
crc_entry(C, K) ->
    case C band 1 of
        1 -> crc_entry((C bsr 1) bxor 16#82F63B78, K - 1);
        0 -> crc_entry(C bsr 1, K - 1)
    end.

crc32c(Bin) ->
    T = crc_table(),
    crc32c(Bin, T, 16#FFFFFFFF) bxor 16#FFFFFFFF.
crc32c(<<>>, _, C) -> C;
crc32c(<<B, R/binary>>, T, C) -> crc32c(R, T, element(((C bxor B) band 16#FF) + 1, T) bxor (C bsr 8)).

varint(N) when N < 128 -> <<N>>;
varint(N) -> <<(N band 127 bor 128), (varint(N bsr 7))/binary>>.

field_varint(F, V) -> <<(varint(F bsl 3))/binary, (varint(V))/binary>>.
field_bytes(F, B) -> <<(varint((F bsl 3) bor 2))/binary, (varint(byte_size(B)))/binary, B/binary>>.

%% BaseCommand.Type numbers (PulsarApi.proto).
command_type(<<"CONNECT">>) -> 2;
command_type(<<"CONNECTED">>) -> 3;
command_type(<<"SUBSCRIBE">>) -> 4;
command_type(<<"PRODUCER">>) -> 5;
command_type(<<"SEND">>) -> 6;
command_type(<<"SEND_RECEIPT">>) -> 7;
command_type(<<"MESSAGE">>) -> 9;
command_type(<<"ACK">>) -> 10;
command_type(<<"FLOW">>) -> 11;
command_type(<<"SUCCESS">>) -> 13;
command_type(<<"PING">>) -> 18;
command_type(<<"PONG">>) -> 19;
command_type(<<"LOOKUP">>) -> 23;
command_type(<<"LOOKUP_RESPONSE">>) -> 24.

command_name(N) ->
    case [C || C <- [<<"CONNECT">>, <<"CONNECTED">>, <<"SUBSCRIBE">>, <<"PRODUCER">>, <<"SEND">>, <<"SEND_RECEIPT">>, <<"MESSAGE">>,
                     <<"ACK">>, <<"FLOW">>, <<"SUCCESS">>, <<"PING">>, <<"PONG">>, <<"LOOKUP">>, <<"LOOKUP_RESPONSE">>],
                command_type(C) =:= N] of
        [C | _] -> C;
        [] -> <<"UNKNOWN">>
    end.

%% The BaseCommand bytes: `type` (field 1) and the inner command (field =
%% type number) holding `Fields` as {FieldNumber, varint | bytes} pairs.
base_command(Name, Fields) ->
    T = command_type(Name),
    Inner = iolist_to_binary([case V of
                                  I when is_integer(I) -> field_varint(F, I);
                                  B when is_binary(B) -> field_bytes(F, B)
                              end || {F, V} <- Fields]),
    <<(field_varint(1, T))/binary, (field_bytes(T, Inner))/binary>>.

encode_simple(Name, Fields) ->
    Cmd = base_command(Name, Fields),
    <<(byte_size(Cmd) + 4):32, (byte_size(Cmd)):32, Cmd/binary>>.

encode_payload(Name, Fields, Metadata, Payload) ->
    Cmd = base_command(Name, Fields),
    Checked = <<(byte_size(Metadata)):32, Metadata/binary, Payload/binary>>,
    Crc = crc32c(Checked),
    Rest = <<16#0e, 16#01, Crc:32, Checked/binary>>,
    <<(4 + byte_size(Cmd) + byte_size(Rest)):32, (byte_size(Cmd)):32, Cmd/binary, Rest/binary>>.

%% {ok, CommandName, Remainder} | more | {error, Reason}
decode(Bin, Max) ->
    case Bin of
        <<Total:32, _/binary>> when Total > Max ->
            {error, iolist_to_binary(["the frame of ", integer_to_binary(Total), " bytes exceeds the maximum of ", integer_to_binary(Max)])};
        <<Total:32, Frame:Total/binary, Rest/binary>> ->
            <<CmdSize:32, Cmd:CmdSize/binary, After/binary>> = Frame,
            case After of
                <<>> -> {ok, command_name(type_of(Cmd)), Rest};
                <<16#0e, 16#01, Crc:32, Checked/binary>> ->
                    case crc32c(Checked) =:= Crc of
                        true -> {ok, command_name(type_of(Cmd)), Rest};
                        false -> {error, <<"checksum mismatch">>}
                    end
            end;
        _ -> more
    end.

type_of(<<8, Rest/binary>>) -> read_varint(Rest, 0, 0);
type_of(_) -> -1.

read_varint(<<B, R/binary>>, Shift, Acc) when B >= 128 -> read_varint(R, Shift + 7, Acc bor ((B band 127) bsl Shift));
read_varint(<<B, _/binary>>, Shift, Acc) -> Acc bor (B bsl Shift).
