execute block
returns (
    dependency_name type of column tmp_dependencies.dependency_name
    , stmt blob sub_type text
)
as
declare dependency_type type of column tmp_dependencies.dependency_type;
declare dependency_field_name type of column tmp_dependencies.dependency_field_name;
declare dependency_level type of column tmp_dependencies.dependency_level;
declare field_list varchar(8192);
declare skip_routines_dependencies smallint;
declare max_level smallint;
declare endl varchar(2) = '
';
begin
    skip_routines_dependencies = 1;
    max_level = 0;

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
        where rdb$procedure_name starts with 'MDS_';
    */
    while (exists(select * from tmp_dependencies where coalesce(is_processed, 0) = 0)) do
    begin
        for select
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
            merge into tmp_dependencies as cur
                using (
                        select
                            rdb$depended_on_type as dependency_type
                            , rdb$depended_on_name as dependency_name
                            , coalesce(rdb$field_name, -1) as dependency_field_name
                        from rdb$dependencies
                        where rdb$dependent_name = :dependency_name
                            and rdb$depended_on_name not starts with upper('RDB$')
                ) as upd
            on cur.dependency_type = upd.dependency_type and cur.dependency_name = upd.dependency_name
                and cur.dependency_field_name is not distinct from upd.dependency_field_name
            when not matched then insert (dependency_type, dependency_name, dependency_field_name, dependency_level, is_processed)
                values(upd.dependency_type, upd.dependency_name, upd.dependency_field_name, :dependency_level + 1
                        , iif((coalesce(:max_level, 0) > 0 and :dependency_level >= :max_level)
                                or (coalesce(:skip_routines_dependencies, 0) > 0 and upd.dependency_type in (2, 5)) -- 2 - trigger; 5 - procedure
                                , -1 -- skip
                                , 0));

            update tmp_dependencies set is_processed = 1 where current of relation;

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
        from tmp_dependencies
        group by 1, 2
        order by 4 desc
        into dependency_type, dependency_name, field_list, dependency_level
    do
    begin
        -- 0 - table
        if(dependency_type = 0) then
        begin
            stmt = 'create table ' || trim(dependency_name) || '(' || :endl
                    || iif(:field_list = '-1'
                        , 'tmp_field smallint'
                        , (select
                            list(trim(f.rdb$field_name)
                                    || ' ' || trim(iif(f.rdb$field_source starts with upper('RDB$')
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
                                      || iif(coalesce(f.rdb$null_flag, 0) = 1, ' not null', '')
                                      || coalesce(' ' || trim(f.rdb$default_source), '')
                              , :endl || ', ')
                        from rdb$relation_fields as f
                            left join rdb$fields as finfo on finfo.rdb$field_name = f.rdb$field_source
                        where f.rdb$relation_name = :dependency_name
                            and (',' || :field_list || ',') like ('%,' || trim(f.rdb$field_name) || ',%')))
                    || endl || ');' || endl;
            suspend;
        end
    end
end