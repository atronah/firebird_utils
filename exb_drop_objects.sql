-- template to create drop statements for all objects except specified in `not in (null)` fragments
execute block
returns (
    name varchar(31)
    , type_name varchar(31)
    , drop_stmt varchar(128)
)
as
begin
    for select
            'trigger' as type_name, rdb$trigger_name as name
        from rdb$triggers
        where rdb$system_flag = 0 and trim(rdb$trigger_name) not in (null)
        union all
        select 'procedure' as type_name, rdb$procedure_name as name
        from rdb$procedures
        where rdb$system_flag = 0 and trim(rdb$procedure_name) not in (null)
        union all
        select
            'view' as type_name, rdb$relation_name as name
        from rdb$relations
        where rdb$system_flag = 0 and rdb$relation_type = 1 -- 1 - view
            and trim(rdb$relation_name) not in (null)
        union all
        select
            'table' as type_name, rdb$relation_name as name
        from rdb$relations
        where rdb$system_flag = 0 and coalesce(rdb$relation_type, 0) = 0 -- 0 - system or user-defined table
            and trim(rdb$relation_name) not in (null)
        union all
        select
            'domain' as type_name, rdb$field_name as name
        from rdb$fields
        where rdb$system_flag = 0 and trim(rdb$field_name) not in (null)
        union all
        select
            'sequence' as type_name, rdb$generator_name as name
        from rdb$generators
        where rdb$system_flag = 0 and trim(rdb$generator_name) not in (null)
        union all
        select
            'index' as type_name, rdb$index_name as name
        from rdb$indices
        where rdb$system_flag = 0 and trim(rdb$index_name) not in (null)
        into type_name, name
    do
    begin
        drop_stmt = 'drop ' || trim(type_name) || ' ' || trim(name) || ';';
        suspend;
    end
end