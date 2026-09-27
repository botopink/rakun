%%% rakun-security — LDAP directory authentication over OTP's `eldap` (front
%%% 79 step 7), plus a small in-node directory server the tests bind against.
%%%
%%% bind-and-search: bind as the service account, search the user by filter
%%% (or build the DN from `userDnPattern`), bind as that DN with the supplied
%%% password, read `memberOf`. Every handle opened is closed on every path;
%%% `handles/0` answers opened minus closed. A wrong password and an unknown
%%% user are the same `rejected`; an unreachable directory is `unavailable`.

-module(rakun_ldap).
-include_lib("eldap/include/eldap.hrl").
-export([authenticate/9, health/4, handles/0, test_server/1, test_stop/0]).

-define(T, rakun_ldap_tab).

counter(Key, D) ->
    case ets:whereis(?T) of
        undefined ->
            Me = self(),
            spawn(fun() ->
                          case (try ets:new(?T, [named_table, public, set]) catch error:badarg -> exists end) of
                              exists -> Me ! ready;
                              _ -> Me ! ready, receive stop -> ok end
                          end
                  end),
            receive ready -> ok after 2000 -> ok end;
        _ -> ok
    end,
    ets:update_counter(?T, Key, D, {Key, 0}).

handles() -> counter(opened, 0) - counter(closed, 0).

open(Host, Port) ->
    case eldap:open([binary_to_list(Host)], [{port, Port}, {timeout, 2000}]) of
        {ok, H} -> counter(opened, 1), {ok, H};
        Err -> Err
    end.

close(H) ->
    _ = (try eldap:close(H) catch _:_ -> ok end),
    counter(closed, 1).

str(B) -> binary_to_list(B).

%% `authenticated\t<dn>\t<g1,g2>`, `rejected` or `unavailable`.
authenticate(Host, Port, ServiceDn, ServicePw, Base, UidAttr, DnPattern, User, Password) ->
    case open(Host, Port) of
        {error, _} -> <<"unavailable">>;
        {ok, H} ->
            try
                Dn = case DnPattern of
                         <<>> ->
                             case eldap:simple_bind(H, str(ServiceDn), str(ServicePw)) of
                                 ok ->
                                     case eldap:search(H, [{base, str(Base)}, {filter, eldap:equalityMatch(str(UidAttr), str(User))},
                                                           {scope, eldap:wholeSubtree()}, {attributes, ["dn"]}]) of
                                         {ok, #eldap_search_result{entries = [#eldap_entry{object_name = D} | _]}} -> D;
                                         _ -> none
                                     end;
                                 _ -> unavailable
                             end;
                         _ -> str(binary:replace(DnPattern, <<"{0}">>, User))
                     end,
                case Dn of
                    unavailable -> <<"unavailable">>;
                    none -> <<"rejected">>;
                    _ when Password =:= <<>> -> <<"rejected">>;
                    _ ->
                        case eldap:simple_bind(H, Dn, str(Password)) of
                            ok ->
                                Groups = case eldap:search(H, [{base, Dn}, {filter, eldap:present("objectClass")},
                                                               {scope, eldap:baseObject()}, {attributes, ["memberOf"]}]) of
                                             {ok, #eldap_search_result{entries = [#eldap_entry{attributes = A} | _]}} ->
                                                 proplists:get_value("memberOf", A, []);
                                             _ -> []
                                         end,
                                iolist_to_binary(["authenticated\t", Dn, "\t",
                                                  lists:join("\n", [G || G <- Groups])]);
                            _ -> <<"rejected">>
                        end
                end
            catch _:_ -> <<"unavailable">>
            after close(H)
            end
    end.

%% `UP`, or `DOWN\t<reason>` — the reason never carries a credential.
health(Host, Port, ServiceDn, ServicePw) ->
    case open(Host, Port) of
        {error, _} -> <<"DOWN\tthe directory is unreachable">>;
        {ok, H} ->
            try eldap:simple_bind(H, str(ServiceDn), str(ServicePw)) of
                ok -> <<"UP">>;
                _ -> <<"DOWN\tthe service account bind failed">>
            catch _:_ -> <<"DOWN\tthe service account bind failed">>
            after close(H)
            end
    end.

%% ═══ the test directory ══════════════════════════════════════════════════════
%% `Entries` is `[{Dn, Password, Uid, Groups}]` as binaries. Answers the port.

test_server(Entries) ->
    Me = self(),
    Pid = spawn(fun() ->
                        {ok, L} = gen_tcp:listen(0, [binary, {packet, asn1}, {active, false}, {reuseaddr, true}]),
                        {ok, Port} = inet:port(L),
                        Me ! {rakun_ldap_port, Port},
                        accept(L, Entries)
                end),
    persistent_term:put(rakun_ldap_test_server, Pid),
    receive {rakun_ldap_port, P} -> P after 2000 -> 0 end.

test_stop() ->
    case persistent_term:get(rakun_ldap_test_server, undefined) of
        undefined -> 0;
        Pid -> exit(Pid, kill), persistent_term:erase(rakun_ldap_test_server), 0
    end.

accept(L, Entries) ->
    case gen_tcp:accept(L) of
        {ok, S} ->
            Pid = spawn(fun() -> receive go -> serve(S, Entries, none) end end),
            ok = gen_tcp:controlling_process(S, Pid),
            Pid ! go,
            accept(L, Entries);
        _ -> ok
    end.

serve(S, Entries, Bound) ->
    case gen_tcp:recv(S, 0, 5000) of
        {ok, Bin} ->
            {ok, {'LDAPMessage', Id, Op, _}} = 'ELDAPv3':decode('LDAPMessage', Bin),
            case Op of
                {bindRequest, {'BindRequest', _V, Name, {simple, Pw}}} ->
                    Ok = lists:any(fun({D, P, _, _}) -> D =:= list_to_binary(Name) andalso P =:= list_to_binary(Pw) end, Entries),
                    Code = case Ok of true -> success; false -> invalidCredentials end,
                    reply(S, Id, {bindResponse, {'BindResponse', Code, "", "", asn1_NOVALUE, asn1_NOVALUE}}),
                    serve(S, Entries, case Ok of true -> Name; false -> Bound end);
                {searchRequest, {'SearchRequest', Base, Scope, _, _, _, _, Filter, _}} ->
                    Hits = case {Scope, Filter} of
                               {baseObject, _} -> [E || {D, _, _, _} = E <- Entries, D =:= list_to_binary(Base)];
                               {_, {equalityMatch, {'AttributeValueAssertion', _, V}}} ->
                                   [E || {_, _, U, _} = E <- Entries, U =:= list_to_binary(V)];
                               _ -> []
                           end,
                    [reply(S, Id, {searchResEntry, {'SearchResultEntry', binary_to_list(D),
                                                    [{'PartialAttribute', "memberOf", [binary_to_list(G) || G <- Gs]}]}})
                     || {D, _, _, Gs} <- Hits],
                    reply(S, Id, {searchResDone, {'LDAPResult', success, "", "", asn1_NOVALUE}}),
                    serve(S, Entries, Bound);
                {unbindRequest, _} -> gen_tcp:close(S);
                _ -> gen_tcp:close(S)
            end;
        _ -> gen_tcp:close(S)
    end.

reply(S, Id, Op) ->
    {ok, Bytes} = 'ELDAPv3':encode('LDAPMessage', {'LDAPMessage', Id, Op, asn1_NOVALUE}),
    gen_tcp:send(S, Bytes).
