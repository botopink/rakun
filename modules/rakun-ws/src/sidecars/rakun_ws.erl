%%% rakun-ws — the XML half of front 93 over OTP's `xmerl`: SOAP 1.1 / 1.2
%%% envelopes, faults, the wrapped element, WS-Security UsernameToken. Every
%%% lookup is by NAMESPACE URI and local name — a document's prefixes
%%% (`soap:`, `s11:`, `env:`, a default namespace) are never assumed.

-module(rakun_ws).
-include_lib("xmerl/include/xmerl.hrl").
-export([envelope/3, body/1, version/1, fault/1, wrapped/1, escape/1, token_header/4, token_of/1, sha256/1]).

-define(NS11, "http://schemas.xmlsoap.org/soap/envelope/").
-define(NS12, "http://www.w3.org/2003/05/soap-envelope").
-define(WSSE, "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd").
-define(WSU, "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd").

ns(<<"1.2">>) -> ?NS12;
ns(_) -> ?NS11.

escape(V) ->
    lists:foldl(fun({F, T}, Acc) -> binary:replace(Acc, F, T, [global]) end, V,
                [{<<"&">>, <<"&amp;">>}, {<<"<">>, <<"&lt;">>}, {<<">">>, <<"&gt;">>}, {<<"\"">>, <<"&quot;">>}, {<<"'">>, <<"&apos;">>}]).

envelope(Version, HeaderXml, BodyXml) ->
    Ns = list_to_binary(ns(Version)),
    Header = case HeaderXml of <<>> -> <<>>; _ -> <<"<soapenv:Header>", HeaderXml/binary, "</soapenv:Header>">> end,
    <<"<?xml version=\"1.0\" encoding=\"UTF-8\"?><soapenv:Envelope xmlns:soapenv=\"", Ns/binary, "\">", Header/binary,
      "<soapenv:Body>", BodyXml/binary, "</soapenv:Body></soapenv:Envelope>">>.

parse(Xml) ->
    try xmerl_scan:string(unicode:characters_to_list(Xml), [{namespace_conformant, true}, {quiet, true}]) of
        {Doc, _} -> {ok, Doc}
    catch _:_ -> error
    end.

local(#xmlElement{nsinfo = {_, L}}) -> L;
local(#xmlElement{name = N}) -> atom_to_list(N).

uri(#xmlElement{namespace = #xmlNamespace{default = D, nodes = Nodes}, nsinfo = Info}) ->
    case Info of
        {Prefix, _} -> case lists:keyfind(Prefix, 1, Nodes) of {_, U} -> atom_to_list(U); false -> "" end;
        [] -> case D of [] -> ""; _ -> atom_to_list(D) end
    end.

children(#xmlElement{content = C}) -> [E || E = #xmlElement{} <- C].

child(E, Name) -> [C || C <- children(E), local(C) =:= Name].

text(E) -> unicode:characters_to_binary(lists:flatten([T#xmlText.value || T = #xmlText{} <- E#xmlElement.content])).

export(Elements) -> unicode:characters_to_binary(xmerl:export_simple_content(Elements, xmerl_xml)).

envelope_of(Xml) ->
    case parse(Xml) of
        {ok, E} ->
            case {local(E), uri(E)} of
                {"Envelope", U} when U =:= ?NS11; U =:= ?NS12 -> {ok, E, U};
                _ -> error
            end;
        error -> error
    end.

version(Xml) ->
    case envelope_of(Xml) of
        {ok, _, ?NS12} -> <<"1.2">>;
        {ok, _, _} -> <<"1.1">>;
        error -> <<>>
    end.

%% The Body's content, re-serialised; `error` when this is no envelope.
body(Xml) ->
    case envelope_of(Xml) of
        {ok, E, U} ->
            case [B || B <- child(E, "Body"), uri(B) =:= U] of
                [B | _] -> export(B#xmlElement.content);
                [] -> error
            end;
        error -> error
    end.

wrapped(Xml) ->
    case envelope_of(Xml) of
        {ok, E, U} ->
            case [B || B <- child(E, "Body"), uri(B) =:= U] of
                [B | _] -> case children(B) of [W | _] -> list_to_binary(local(W)); [] -> <<>> end;
                [] -> <<>>
            end;
        error -> <<>>
    end.

%% {Code, Reason, Actor, DetailXml} from an envelope, or `none`.
fault(Xml) ->
    case envelope_of(Xml) of
        {ok, E, U} ->
            Faults = [F || B <- child(E, "Body"), F <- child(B, "Fault")],
            case {Faults, U} of
                {[], _} -> none;
                {[F | _], ?NS11} ->
                    {first_text(F, "faultcode"), first_text(F, "faultstring"), first_text(F, "faultactor"), detail(F, "detail")};
                {[F | _], _} ->
                    Code = case child(F, "Code") of [C | _] -> first_text(C, "Value"); [] -> <<>> end,
                    Reason = case child(F, "Reason") of [R | _] -> first_text(R, "Text"); [] -> <<>> end,
                    {Code, Reason, first_text(F, "Role"), detail(F, "Detail")}
            end;
        error -> none
    end.

first_text(E, Name) -> case child(E, Name) of [C | _] -> text(C); [] -> <<>> end.
detail(E, Name) -> case child(E, Name) of [D | _] -> export(D#xmlElement.content); [] -> <<>> end.

token_header(User, Pass, Nonce, Created) ->
    <<"<wsse:Security xmlns:wsse=\"", ?WSSE, "\" xmlns:wsu=\"", ?WSU, "\"><wsse:UsernameToken><wsse:Username>", (escape(User))/binary,
      "</wsse:Username><wsse:Password Type=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText\">",
      (escape(Pass))/binary, "</wsse:Password><wsse:Nonce>", Nonce/binary, "</wsse:Nonce><wsu:Created>", Created/binary,
      "</wsu:Created></wsse:UsernameToken></wsse:Security>">>.

%% {User, Pass, Nonce, Created} from an envelope's Security header, or none.
token_of(Xml) ->
    case envelope_of(Xml) of
        {ok, E, _} ->
            Tokens = [T || H <- child(E, "Header"), S <- child(H, "Security"), T <- child(S, "UsernameToken")],
            case Tokens of
                [T | _] -> {first_text(T, "Username"), first_text(T, "Password"), first_text(T, "Nonce"), first_text(T, "Created")};
                [] -> none
            end;
        error -> none
    end.

sha256(B) -> binary:encode_hex(crypto:hash(sha256, B), lowercase).
