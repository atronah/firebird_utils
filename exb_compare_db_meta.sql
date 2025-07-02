execute block
returns (
    object_type type of column rdb$dependencies.rdb$dependent_type
    , object_name varchar(31)
    , create_stmt blob sub_type text
    , other_db_create_stmt blob sub_type text
    , other_db varchar(255)
)
as
--
declare TYPE_TABLE type of column rdb$dependencies.rdb$dependent_type = 0;
declare TYPE_VIEW type of column rdb$dependencies.rdb$dependent_type = 1;
declare TYPE_TRIGGER type of column rdb$dependencies.rdb$dependent_type = 2;
declare TYPE_PROCEDURE type of column rdb$dependencies.rdb$dependent_type = 5;
--
declare TABLE_TYPE_VIEW type of column rdb$relations.rdb$relation_type = 1; -- 1 - view
begin
    other_db = ;

    for select
            :TYPE_TABLE as t
            , trim(rdb$relation_name) as name
        from rdb$relations
        where coalesce(rdb$system_flag, 0) = 0
            and rdb$relation_type is distinct from :TABLE_TYPE_VIEW
        union all
        select
            :TYPE_PROCEDURE as t
            , trim(rdb$procedure_name) as name
        from rdb$procedures
        where coalesce(rdb$system_flag, 0) = 0
            and rdb$package_name is null
        union all
        select
            :TYPE_TRIGGER as t
            , trim(rdb$trigger_name) as name
        from rdb$triggers
        where coalesce(rdb$system_flag, 0) = 0
        union all
        select
            :TYPE_VIEW as t
            , trim(rdb$relation_name) as name
        from rdb$relations
        where coalesce(rdb$system_flag, 0) = 0
            and rdb$relation_type is NOT distinct from :TABLE_TYPE_VIEW
        order by 1, 2
        into object_type, object_name
    do
    begin
        create_stmt = (select stmt from aux_get_create_statement(:object_name, :object_type, null, 0, 0, 1));

        if (other_db > '') then
        begin
            other_db_create_stmt = null;
            execute statement ('select stmt from aux_get_create_statement(:object_name, :object_type, null, 0, 0, 1)')
                (object_name := :object_name, object_type := :object_type)
                on external other_db
                into other_db_create_stmt;
        end
        else other_db_create_stmt = create_stmt;

        if (create_stmt is distinct from other_db_create_stmt)
            then suspend;
    end
end
