execute block
returns (
    dependency_name type of column tmp_dependencies.dependency_name
    , stmt blob sub_type text
)
as
declare dependency_type type of column tmp_dependencies.dependency_type;
declare dependency_field_name type of column tmp_dependencies.dependency_field_name;
declare dependency_level type of column tmp_dependencies.dependency_level;
declare is_processed type of column tmp_dependencies.is_processed;

declare slave_dependency_name type of column tmp_dependencies.dependency_name;
declare slave_dependency_type type of column tmp_dependencies.dependency_type;
declare slave_dependency_field_name type of column tmp_dependencies.dependency_field_name;
declare slave_dependency_level type of column tmp_dependencies.dependency_level;
declare slave_is_processed type of column tmp_dependencies.is_processed;

declare field_list varchar(8192);
declare skip_routines_dependencies smallint;
declare endl varchar(2) = '
';
begin
    skip_routines_dependencies = 0;

    /*
    recreate table tmp_dependencies(
        dependency_type smallint
        , dependency_name varchar(31)
        , dependency_field_name varchar(31)
        , dependency_level smallint
        , is_processed smallint
        , constraint pk_tmp_dependencies primary key (dependency_type, dependency_name, dependency_field_name)
    );

    insert into tmp_dependencies
        (dependency_type, dependency_name, dependency_field_name, dependency_level, is_processed)
        select distinct
            5 as dependency_type -- 5 - procedure
            , rdb$procedure_name as dependency_name
            , -1 as dependency_field_name
            , 0 as dependency_level
            , 0 as is_processed
        from rdb$procedures
        where rdb$procedure_name starts with 'MDS_EIS';

    insert into tmp_dependencies
        (dependency_type, dependency_name, dependency_field_name, dependency_level, is_processed)
        select distinct
            2 as dependency_type -- 2 - trigger
            , rdb$trigger_name as dependency_name
            , -1 as dependency_field_name
            , 0 as dependency_level
            , 0 as is_processed
        from rdb$triggers
        where rdb$trigger_name starts with 'MDS_EIS';

    insert into tmp_dependencies
        (dependency_type, dependency_name, dependency_field_name, dependency_level, is_processed)
        select distinct
            5 as dependency_type -- 5 - procedure
            , rdb$relation_name as dependency_name
            , -1 as dependency_field_name
            , 0 as dependency_level
            , 0 as is_processed
        from rdb$relations
        where rdb$relation_name starts with 'MDS_EIS'
            and rdb$relation_type in (0, 1);
    */
    while (exists(select * from tmp_dependencies where coalesce(is_processed, 0) = 0)) do
    begin
        for select
                /*
                trim(decode(
                    , 0, 'table'
                    , 1, 'view'
                    , 2, 'trigger'
                    , 3, 'computed column'
                    , 4, 'constraint'
                    , 5, 'procedure'
                    , 6, 'index'
                    , 7, 'exception'
                    , 8, 'user'
                    , 9, 'column'
                    , 10, 'index'
                    , 14, 'sequence'
                    , 15, 'UDF'
                    , 17, 'collation'
                    , null
                )) as dependency_type
                */
                dependency_type
                , dependency_name
                , dependency_field_name
                , dependency_level
            from tmp_dependencies
            where coalesce(is_processed, 0) = 0
            into dependency_type, dependency_name, dependency_field_name, dependency_level
            as cursor relation
        do
        begin
            is_processed = 1;
            for with slaves as (
                    select
                        rdb$depended_on_type as dependency_type
                        , rdb$depended_on_name as dependency_name
                        , coalesce(rdb$field_name, -1) as dependency_field_name
                    from rdb$dependencies
                    where rdb$dependent_name = :dependency_name
                        and rdb$depended_on_name not starts with upper('RDB$')
                        and rdb$depended_on_type is distinct from 17
                    union
                    -- domains of table fields
                    select
                        9 as dependency_type -- 9 - column/domain
                        , rdb$field_source as dependency_name
                        , -1 as dependency_field_name
                    from rdb$relation_fields
                    where rdb$relation_name = :dependency_name
                        and rdb$field_source not starts with upper('RDB$')
                    union
                    -- domains of procedure params
                    select
                        9 as dependency_type -- 9 - column/domain
                        , rdb$field_source as dependency_name
                        , -1 as dependency_field_name
                    from rdb$procedure_parameters
                    where rdb$procedure_name = :dependency_name
                        and rdb$field_source not starts with upper('RDB$')
                )
                select distinct
                        slaves.dependency_type
                        , slaves.dependency_name
                        , slaves.dependency_field_name
                        , existed.dependency_level
                        , existed.is_processed as slave_is_processed
                    from slaves
                        left join tmp_dependencies as existed on existed.dependency_type = slaves.dependency_type
                                                                    and existed.dependency_name = slaves.dependency_name
                                                                    and existed.dependency_field_name = slaves.dependency_field_name
                    order by existed.is_processed desc
                into slave_dependency_type, slave_dependency_name, slave_dependency_field_name, slave_dependency_level
                    , slave_is_processed
            do
            begin
                if (slave_is_processed > 0 and slave_dependency_level >= dependency_level)
                    then dependency_level = slave_dependency_level + 1;

                if (slave_is_processed is null) then
                begin
                    is_processed = 0;
                    insert into tmp_dependencies
                                (dependency_type, dependency_name, dependency_field_name, dependency_level, is_processed)
                        values  (:slave_dependency_type, :slave_dependency_name, :slave_dependency_field_name
                                -- dependency_level
                                , decode(:slave_dependency_type
                                            , 14, 1 -- 14 - sequence
                                            , 7, 2 -- 7 - exception
                                            , 9, 3 -- 9 - column/domain
                                            , 0, 4 -- 0 - table
                                            , 1, 5 -- 1 - view
                                            , 6)
                                -- is_processed
                                , iif((coalesce(:skip_routines_dependencies, 0) > 0 and :slave_dependency_type in (2, 5)) -- 2 - trigger; 5 - procedure
                                        , 2 -- skip
                                        , 0)
                                );
                end
            end
            
            if (is_processed > 0) then
            begin
                update tmp_dependencies
                    set is_processed = :is_processed
                        -- do not update dependency_level for base items with zero dependency_level
                        , dependency_level = iif(dependency_level > 0, :dependency_level, 0)
                    where current of relation;
            end

            /*
            trim(decode(
                , 0, 'table'
                , 1, 'view'
                , 2, 'trigger'
                , 3, 'computed column'
                , 4, 'constraint'
                , 5, 'procedure'
                , 6, 'index'
                , 7, 'exception'
                , 8, 'user'
                , 9, 'column'
                , 10, 'index'
                , 14, 'sequence'
                , 15, 'UDF'
                , 17, 'collation'
                , null
            )) as dependency_type
            */
        end
    end


    for select
            dependency_type
            , dependency_name
            , list(trim(dependency_field_name)) as field_list
            , max(dependency_level) as dependency_level
            , max(is_processed) as is_processed
        from tmp_dependencies
        where dependency_level > 0
            and is_processed > 0
        group by 1, 2
        order by 4 asc
        into dependency_type, dependency_name, field_list, dependency_level, is_processed
    do
    begin
        -- 0 - table
        if(dependency_type = 0) then
        begin
            stmt = 'create table ' || trim(dependency_name) || '(' || :endl || '    '
                    || iif(:field_list = '-1'
                        , 'tmp_field smallint'
                        , (select
                            list(trim(f.rdb$field_name)
                                    || ' '
                                    || trim(iif(f.rdb$field_source starts with upper('RDB$')
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
                                    || trim(iif(f.rdb$field_source starts with upper('RDB$') and finfo.rdb$field_type in (14, 37)
                                                    , '(' || finfo.rdb$field_length || ')'
                                                    , ''))
                                    || coalesce(' ' || trim(f.rdb$default_source), '')
                                    || iif(coalesce(f.rdb$null_flag, 0) = 1, ' not null', '')
                              , :endl || '    , ')
                        from rdb$relation_fields as f
                            left join rdb$fields as finfo on finfo.rdb$field_name = f.rdb$field_source
                        where f.rdb$relation_name = :dependency_name
                            and ((',' || :field_list || ',') like ('%,' || trim(f.rdb$field_name) || ',%') -- or field exists in table dependencies
                                    or exists(select f.rdb$field_name -- or field is a part of primary key
                                                from rdb$relation_constraints as c
                                                    inner join rdb$index_segments as idxs on idxs.rdb$index_name = c.rdb$index_name
                                                where c.rdb$relation_name = :dependency_name
                                                    and c.rdb$constraint_type containing 'primary key'
                                                    and idxs.rdb$field_name = f.rdb$field_name))
                            )
                        ) || endl
                    || (select
                            ', constraint ' || trim(max(c.rdb$constraint_name))
                                || ' primary key (' || list(trim(idxs.rdb$field_name)) || ')'
                        from rdb$relation_constraints as c
                            inner join rdb$indices as idx on idx.rdb$index_name = c.rdb$index_name
                            inner join rdb$index_segments as idxs on idxs.rdb$index_name = idx.rdb$index_name
                        where c.rdb$relation_name = :dependency_name
                            and c.rdb$constraint_type containing 'primary key') || endl
                    || ');' || endl;
            suspend;
        end
        -- 1 - view
        else if(dependency_type = 1) then
        begin
            stmt = 'create view ' || trim(dependency_name) || endl
                || ' as ' || endl
                || (select rdb$view_source from rdb$relations where rdb$relation_name = :dependency_name)
                || ';' || endl;
            suspend;
        end
        -- 5 - procedure
        else if(dependency_type = 5) then
        begin
            stmt = null;

            select
                'set term ^ ;' || :endl
                    || 'create procedure ' || trim(rdb$procedure_name)
                    || coalesce((select '(' || :endl || '    '
                                        || list(trim(rdb$parameter_name)
                                                    || ' '
                                                    || iif(:is_processed = 2
                                                            -- dummy type for skipped procedures
                                                            , 'varchar(1) = null'
                                                            , trim(iif(params.rdb$field_source starts with upper('RDB$')
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
                                                                        , params.rdb$field_source))
                                                                || trim(iif(params.rdb$field_source starts with upper('RDB$') and finfo.rdb$field_type in (14, 37)
                                                                                , '(' || finfo.rdb$field_length || ')'
                                                                                , ''))
                                                                || coalesce(' ' || trim(params.rdb$default_source), '')

                                                            )
                                                , :endl || '    , ') || :endl
                                        || ')' || :endl
                                    from rdb$procedure_parameters as params
                                        left join rdb$fields as finfo on finfo.rdb$field_name = params.rdb$field_source
                                    where params.rdb$procedure_name = p.rdb$procedure_name
                                        and (:is_processed <> 2
                                            -- for skipped only dummy params with dependencies
                                            or (:is_processed = 2 and (',' || :field_list || ',') like ('%,' || trim(params.rdb$parameter_name) || ',%')))
                                        and rdb$parameter_type = 0 -- 1 - output param
                                        )
                                , '') || :endl
                    || coalesce((select 'returns (' || :endl || '    '
                                        || list(trim(rdb$parameter_name)
                                                    || ' '
                                                    || iif(:is_processed = 2
                                                            -- dummy type for skipped procedures
                                                            , 'varchar(1) = null'
                                                            , trim(iif(params.rdb$field_source starts with upper('RDB$')
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
                                                                        , params.rdb$field_source))
                                                                || trim(iif(params.rdb$field_source starts with upper('RDB$') and finfo.rdb$field_type in (14, 37)
                                                                                , '(' || finfo.rdb$field_length || ')'
                                                                                , ''))
                                                                || coalesce(' ' || trim(params.rdb$default_source), '')

                                                            )
                                                , :endl || '    , ') || :endl
                                        || ')' || :endl
                                    from rdb$procedure_parameters as params
                                        left join rdb$fields as finfo on finfo.rdb$field_name = params.rdb$field_source
                                    where params.rdb$procedure_name = p.rdb$procedure_name
                                        and (:is_processed <> 2
                                            -- for skipped only dummy params with dependencies
                                            or (:is_processed = 2 and (',' || :field_list || ',') like ('%,' || trim(params.rdb$parameter_name) || ',%')))
                                        and rdb$parameter_type = 1 -- 1 - output param
                                        )
                                , '') || :endl
                    || ' as ' || :endl
                    || iif(:is_processed = 2 -- skipped
                            , 'begin' || :endl
                                || iif(:field_list <> '-1', 'suspend;' || :endl, '')
                                || 'end'
                            , rdb$procedure_source
                        ) || '^' ||  :endl
                    || 'set term ; ^' || :endl
                from rdb$procedures as p
                where coalesce(p.rdb$system_flag, 0) = 0
                    and p.rdb$procedure_name = :dependency_name
                into stmt;
            suspend;
        end
        -- 7 - exception
        else if(dependency_type = 7) then
        begin
            stmt = 'create exception ' || trim(dependency_name)
                || ' '''
                || (select rdb$message from rdb$exceptions where rdb$exception_name = :dependency_name)
                || ''';' || endl;
            suspend;
        end
        -- 9 - column/domain
        else if(dependency_type = 9) then
        begin
            stmt = 'create domain ' || trim(dependency_name)
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
                    where finfo.rdb$field_name = :dependency_name
                    )
                || ';' || endl;
            suspend;
        end
        -- 14 - sequence
        else if(dependency_type = 14) then
        begin
            stmt = 'create sequence ' || trim(dependency_name) || ';' || endl;
            suspend;
        end
    end

    stmt = 'commit;';
    suspend;
end