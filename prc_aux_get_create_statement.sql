set term ^ ;

create or alter procedure aux_get_create_statement(
    object_name_in varchar(31)
    , object_type_in smallint = null -- has the same values as RDB$DEPENDENCIES.RDB$DEPENDED_ON_TYPE
    , only_fields varchar(8192) = null -- if is null - add all fields, otherwise add only specified fields
    , create_dummy smallint = 0
    , add_commit smallint = 0 -- 0 - do not add `commit`; 1 - add `commit` after statement;
)
returns(
    stmt blob sub_type text
    , object_name varchar(31)
    , object_type smallint
    , object_type_name varchar(16)
)
as
declare field_name varchar(31);
declare field_type varchar(31);
declare field_params varchar(64);
declare constraint_name varchar(31);
declare is_begin smallint;
declare repeater smallint;
-- constants
declare TYPE_TABLE smallint = 0;
declare TYPE_VIEW smallint = 1;
-- declare TYPE_TRIGGER smallint = 2;
-- declare TYPE_COMPUTED_COLUMN smallint = 3;
-- declare TYPE_CONSTRAINT smallint = 4;
declare TYPE_PROCEDURE smallint = 5;
-- declare TYPE_INDEX_EXPRESSION smallint = 6;
declare TYPE_EXCEPTION smallint = 7;
-- declare TYPE_USER smallint = 8;
declare TYPE_DOMAIN smallint = 9;
-- declare TYPE_INDEX smallint = 10;
declare TYPE_SEQUENCE smallint = 14;
-- declare TYPE_UDF smallint = 15;
-- declare TYPE_COLLATION smallint = 17;
declare endl varchar(2) = '
';
begin
    object_type = object_type_in;
    object_name = object_name_in;

    if (object_type is null) then
    begin
        object_type = case
            when exists(select rdb$procedure_name
                    from rdb$procedures
                    where trim(lower(rdb$procedure_name)) = trim(lower(:object_name_in)))
                then TYPE_PROCEDURE
            when exists(select RDB$FIELD_NAME
                    from RDB$FIELDS
                    where trim(lower(RDB$FIELD_NAME)) = trim(lower(:object_name_in)))
                then TYPE_DOMAIN
            when exists(select rdb$exception_name
                    from rdb$exceptions
                    where trim(lower(rdb$exception_name)) = trim(lower(:object_name_in)))
                then TYPE_EXCEPTION
            when exists(select rdb$generator_name
                    from rdb$generators
                    where trim(lower(rdb$generator_name)) = trim(lower(:object_name_in)))
                then TYPE_SEQUENCE
            else (select rdb$relation_type
                    from rdb$relations
                    where trim(lower(rdb$relation_name)) = trim(lower(:object_name_in))
                        and rdb$relation_type in (:TYPE_TABLE, :TYPE_VIEW))
            end;
    end

    if (object_type is null) then exit;

    object_type_name =  case object_type
                                when TYPE_TABLE then 'table'
                                when TYPE_VIEW then 'view'
                                -- when TYPE_TRIGGER then 'trigger'
                                -- when TYPE_COMPUTED_COLUMN then 'computed column'
                                -- when TYPE_CONSTRAINT then 'constraint'
                                when TYPE_PROCEDURE then 'procedure'
                                -- when TYPE_INDEX_EXPRESSION then 'index expression'
                                when TYPE_EXCEPTION then 'exception'
                                -- when TYPE_USER then 'user'
                                when TYPE_DOMAIN then 'domain'
                                -- when TYPE_INDEX then 'index'
                                when TYPE_SEQUENCE then 'sequence'
                                -- when TYPE_UDF then 'UDF'
                                -- when TYPE_COLLATION then 'collation'
                        end;

    if(object_type = TYPE_TABLE) then
    begin
        stmt = 'create table ' || trim(object_name) || '(' || :endl;

        is_begin = 1;
        for select
                trim(f.rdb$field_name) as field_name
                , iif(:create_dummy > 0
                        , 'varchar(1024)'
                        , trim(iif(f.rdb$field_source starts with upper('RDB$')
                                            , decode(finfo.rdb$field_type
                                                    , 7, 'smallint'
                                                    , 8, 'integer'
                                                    , 10, 'float'
                                                    , 12, 'date'
                                                    , 13, 'time'
                                                    , 14, 'char'
                                                    , 16, 'bigint'
                                                    , 27, 'double precision'
                                                    , 35, 'timestamp'
                                                    , 37, 'varchar'
                                                    , 261, 'blob')
                                            , f.rdb$field_source))
                            || trim(iif(f.rdb$field_source starts with upper('RDB$') and finfo.rdb$field_type in (14, 37) -- char/varchar
                                        , '(' || finfo.rdb$field_length || ')'
                                        , ''))
                ) as field_type
                , coalesce(trim(f.rdb$default_source), '')
                    || iif(coalesce(f.rdb$null_flag, 0) = 1, ' not null', '') as field_params
            from rdb$relation_fields as f
                left join rdb$fields as finfo on finfo.rdb$field_name = f.rdb$field_source
            where f.rdb$relation_name = :object_name
                and (
                    :only_fields is null
                    or (',' || :only_fields || ',') like ('%,' || trim(f.rdb$field_name) || ',%') -- or field exists in table dependencies
                        or exists(select f.rdb$field_name -- or field is a part of primary key
                                    from rdb$relation_constraints as c
                                        inner join rdb$index_segments as idxs on idxs.rdb$index_name = c.rdb$index_name
                                    where c.rdb$relation_name = :object_name
                                        and c.rdb$constraint_type containing 'primary key'
                                        and idxs.rdb$field_name = f.rdb$field_name)
                    )
            order by f.rdb$field_position asc
            into field_name, field_type, field_params
        do
        begin
            stmt = stmt
                || iif(is_begin > 0, '', '    , ')
                || field_name || ' ' || field_type || ' ' || field_params || endl;
            is_begin = 0;
        end
        if (row_count = 0) then exit;

        is_begin = 1;
        for select
                trim(c.rdb$constraint_name) as constraint_name
                , trim(idxs.rdb$field_name) as field_name
            from rdb$relation_constraints as c
                inner join rdb$indices as idx on idx.rdb$index_name = c.rdb$index_name
                inner join rdb$index_segments as idxs on idxs.rdb$index_name = idx.rdb$index_name
            where c.rdb$relation_name = :object_name
                and c.rdb$constraint_type containing 'primary key'
            order by idxs.rdb$field_position
            into constraint_name, field_name
        do
        begin
            stmt = stmt
                || iif(is_begin > 0
                        , '    , constraint ' || constraint_name || ' primary key ('
                        , '    , ')
                || field_name;
            is_begin = 0;
        end
        if (row_count > 0) then stmt = stmt || ')' || endl;
        stmt = stmt || ');';
    end
    else if(object_type = TYPE_VIEW) then
    begin
        stmt = 'create view ' || trim(object_name) || endl
            || ' as ' || endl
            || (select rdb$view_source from rdb$relations where rdb$relation_name = :object_name)
            || ';';
    end
    else if(object_type = TYPE_PROCEDURE) then
    begin
        if (not exists(select rdb$procedure_name
                        from rdb$procedures
                        where trim(lower(rdb$procedure_name)) = trim(lower(:object_name))
                            and coalesce(rdb$system_flag, 0) = 0)) then exit;

        stmt = 'set term ^ ;' || endl
                || 'create procedure ' || trim(:object_name);

        repeater = 0;
        while (repeater < 2) do
        begin
            is_begin = 1;
            for select
                    trim(rdb$parameter_name)
                    , trim(iif(p.rdb$field_source starts with upper('RDB$')
                                    , decode(finfo.rdb$field_type
                                            , 7, 'smallint'
                                            , 8, 'integer'
                                            , 10, 'float'
                                            , 12, 'date'
                                            , 13, 'time'
                                            , 14, 'char'
                                            , 16, 'bigint'
                                            , 27, 'double precision'
                                            , 35, 'timestamp'
                                            , 37, 'varchar'
                                            , 261, 'blob')
                                    , p.rdb$field_source))
                            || trim(iif(p.rdb$field_source starts with upper('RDB$') and finfo.rdb$field_type in (14, 37)
                                            , '(' || finfo.rdb$field_length || ')'
                                            , '')) as field_type
                    , coalesce(' ' || trim(coalesce(p.rdb$default_source, finfo.rdb$default_source)), '') as field_params
                from rdb$procedure_parameters as p
                    left join rdb$fields as finfo on finfo.rdb$field_name = p.rdb$field_source
                where p.rdb$procedure_name = :object_name
                                        and (:create_dummy = 0
                                            -- for skipped only dummy params with dependencies
                                            or (:create_dummy > 0 and (',' || :only_fields || ',') like ('%,' || trim(p.rdb$parameter_name) || ',%')))
                                        and rdb$parameter_type = :repeater -- 0 - input param, 1 - output param
                                    order by p.rdb$parameter_number
                into field_name, field_type, field_params
            do
            begin
                stmt = stmt
                    || iif(is_begin > 0
                            , iif(repeater = 1, endl || 'returns', '') || '(' || endl || '    '
                            , '    , ')
                    || field_name || ' ' || field_type || ' ' || field_params || endl;
                is_begin = 0;
            end
            if (row_count > 0) then stmt = stmt || ')' || endl;

            repeater = repeater + 1;
        end

        stmt = stmt
            || 'as' || endl
            || iif(create_dummy > 0 -- skipped
                    , 'begin' || endl
                        || iif(stmt containing 'returns(', 'suspend;', '') || endl
                        || 'end'
                    , (select rdb$procedure_source from rdb$procedures where trim(lower(rdb$procedure_name)) = trim(lower(:object_name)))
                )
            || '^' || endl
            || 'set term ; ^';
    end
    else if(object_type = TYPE_EXCEPTION) then
    begin
        stmt = 'create exception ' || trim(object_name)
            || ' '''
            || (select rdb$message from rdb$exceptions where rdb$exception_name = :object_name)
            || ''';';
    end
    else if(object_type = TYPE_DOMAIN) then
    begin
        stmt = 'create domain ' || trim(object_name)
            || ' as '
            || (select
                    trim(decode(finfo.rdb$field_type
                                , 7, 'smallint'
                                , 8, 'integer'
                                , 10, 'float'
                                , 12, 'date'
                                , 13, 'time'
                                , 14, 'char'
                                , 16, 'bigint'
                                , 27, 'double precision'
                                , 35, 'timestamp'
                                , 37, 'varchar'
                                , 261, 'blob'))
                        || trim(iif(finfo.rdb$field_type in (14, 37)
                                                , '(' || finfo.rdb$field_length || ')'
                                                , ''))
                        || iif(coalesce(finfo.rdb$null_flag, 0) = 1, ' not null', '')
                        || coalesce(' ' || trim(finfo.rdb$default_source), '')
                from rdb$fields as finfo
                where finfo.rdb$field_name = :object_name
                )
            || ';';
    end
    else if(object_type = TYPE_SEQUENCE) then
    begin
        stmt = 'create sequence ' || trim(object_name) || ';' || endl
                || iif(add_commit = 2, 'commit;' || endl, '');
    end

    stmt = stmt || endl;

    if (add_commit > 0) then
    begin
        stmt = stmt || 'commit;' || endl;
    end

    suspend;
end^

set term ; ^