-- Makes drop-queries for all objects except which has specified prefix.
-- Useful for remove unnecessary objects to make test database
-- (dropping necessary objects falls with dependencies error)
execute block
returns(
    obj_type varchar(16)
    , stmt blob sub_type text
    , obj_count bigint
)
as
declare name_prefix varchar(31);
begin
    name_prefix = 'MDS_';

    for select
            obj_type
            , list(distinct 'drop ' || trim (obj_type) || ' ' || obj_name || ';'
                    , ascii_char(13) || ascii_char(10)
            ) as stmt
            , count(*) as obj_count
        from (
            select 'table' as obj_type, trim(rdb$relation_name) as obj_name
            from rdb$relations
            where coalesce(rdb$relation_type, 0) in (0, 4, 5) -- 0 - system or user-defined table; 4/5 - GTT (connection/transaction level)
                and coalesce(rdb$system_flag, 0) = 0
                and trim(rdb$relation_name) not starts with :name_prefix
            union
            select 'view' as obj_type, trim(rdb$relation_name) as obj_name
            from rdb$relations
            where rdb$relation_type = 1 -- 1 - view
                and coalesce(rdb$system_flag, 0) = 0
                and trim(rdb$relation_name) not starts with :name_prefix
            union
            select 'trigger' as obj_type, trim(rdb$trigger_name) as obj_name
            from rdb$triggers
            where coalesce(rdb$system_flag, 0) = 0
                and trim(rdb$trigger_name) not starts with :name_prefix
            union
            select 'procedure' as obj_type, trim(rdb$procedure_name) as obj_name
            from rdb$procedures
            where coalesce(rdb$system_flag, 0) = 0
                and trim(rdb$procedure_name) not starts with :name_prefix
            union
            select 'domain' as obj_type, trim(rdb$field_name) as obj_name
            from rdb$fields
            where coalesce(rdb$system_flag, 0) = 0
                and trim(rdb$field_name) not starts with :name_prefix
            union
            select 'index' as obj_type, trim(rdb$index_name) as obj_name
            from rdb$indices
            where coalesce(rdb$system_flag, 0) = 0
                and trim(rdb$index_name) not starts with :name_prefix
            union
            select 'sequence' as obj_type, trim(rdb$generator_name) as obj_name
            from rdb$generators
            where coalesce(rdb$system_flag, 0) = 0
                and trim(rdb$generator_name) not starts with :name_prefix
        )
        group by 1
        into obj_type, stmt, obj_count
    do suspend;
end
