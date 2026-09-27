%%% rakun-data — the entity registry (front 78 step 8) and the two values
%%% the mappers stamp: the time and the principal.
%%%
%%% `#[entity]` registers an `EntityMeta` at module load; front 77's
%%% `ddl-auto` reads the tables, their columns and their types from here. A
%%% `#[revisions]` entity registers its revision table the same way.

-module(rakun_orm).
-export([register/1, entity_names/0, entity_table/1, table_columns/1, column_type/2, tables/0,
         meta_of_table/1, now_iso/0, principal/0]).

%% EntityMeta: {Tag, Entity, Table, Columns, Types, IdColumn, Generated, VersionColumn, Revisions}
register(Meta) ->
    Entity = element(2, Meta),
    persistent_term:put({rakun_orm, entity, Entity}, Meta),
    persistent_term:put(rakun_orm_names, lists:usort([Entity | entity_list()])),
    0.

entity_list() -> persistent_term:get(rakun_orm_names, []).

metas() -> [persistent_term:get({rakun_orm, entity, E}) || E <- entity_list()].

entity_names() -> entity_list().

entity_table(Entity) ->
    case persistent_term:get({rakun_orm, entity, Entity}, undefined) of
        undefined -> <<>>;
        M -> element(3, M)
    end.

tables() -> lists:usort([element(3, M) || M <- metas()]).

meta_of_table(Table) ->
    case [M || M <- metas(), element(3, M) =:= Table] of
        [M | _] -> M;
        [] -> undefined
    end.

table_columns(Table) ->
    case meta_of_table(Table) of
        undefined -> <<>>;
        M -> element(4, M)
    end.

column_type(Table, Column) ->
    case meta_of_table(Table) of
        undefined -> <<>>;
        M ->
            Pairs = [binary:split(P, <<":">>) || P <- binary:split(element(5, M), <<"|">>, [global]), P =/= <<>>],
            case [T || [C, T] <- Pairs, C =:= Column] of
                [T | _] -> T;
                [] -> <<>>
            end
    end.

now_iso() ->
    list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(microsecond), [{unit, microsecond}, {offset, "Z"}])).

%% Front 10's principal name, `<<>>` outside a request or without front 10.
principal() ->
    case erlang:function_exported(rakun_security, wire, 0) of
        true ->
            case binary:split(rakun_security:wire(), <<"\t">>, [global]) of
                [_, _, Name | _] -> Name;
                _ -> <<>>
            end;
        false ->
            case get(rakun_orm_test_principal) of
                undefined -> <<>>;
                P -> P
            end
    end.
