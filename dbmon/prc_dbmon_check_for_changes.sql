set term ^ ;

create or alter procedure dbmon_check_for_changes(
    db_connection type of column dbmon_structure_changelog.db_name = null
    , db_user varchar(32)= null
    , db_password varchar(8) = null
    , db_role varchar(32) = null
)
as
declare db_name type of column dbmon_structure_changelog.db_name;
declare object_type type of column dbmon_structure_changelog.object_type;
declare object_name type of column dbmon_structure_changelog.object_name;

declare prev_change_id type of column dbmon_structure_changelog.change_id;
declare prev_create_statement type of column dbmon_structure_changelog.sql_text;

declare create_statement type of column dbmon_structure_changelog.sql_text;
declare checked type of column dbmon_structure_changelog.checked;
declare get_objects_stmt varchar(1024);
declare CHANGE_TYPE_BY_CREATE_STMT type of column dbmon_structure_changelog.change_type = 'DBMON_CHECK_FOR_CHANGES';
begin
    db_name = coalesce(db_connection, rdb$get_context('SYSTEM', 'DB_NAME'));

    for select
            trim(t) as object_type
            , trim(s) as get_objects_stmt
        from (
            select 'procedure' as t
                    , 'select rdb$procedure_name from rdb$procedures where coalesce(rdb$system_flag, 0) = 0' as s
                from rdb$database union
            select 'table' as t
                    , 'select rdb$relation_name
                            from rdb$relations
                            where coalesce(rdb$system_flag, 0) = 0
                            and coalesce(rdb$relation_type, 0) = 0
                    ' as s
                from rdb$database union
            select 'trigger' as t
                    , 'select rdb$trigger_name
                            from rdb$triggers
                            where coalesce(rdb$system_flag, 0) = 0
                    ' as s
                from rdb$database
        )
        into object_type, get_objects_stmt
    do
    begin
        object_type = upper(trim(object_type));

        for execute statement get_objects_stmt
            on external db_connection as user db_user password db_password role db_role
            into object_name
        do
        begin
            object_name = upper(trim(object_name));
            checked = cast('now' as timestamp);

            create_statement = null;
            -- aux_get_create_statement - procedure from project github.com/atronah/firebird_utils
            execute statement
                ('select stmt from aux_get_create_statement(:object_name)')
                (object_name := :object_name)
                on external db_connection as user db_user password db_password role db_role
                into create_statement;

            prev_change_id = null; prev_create_statement = null;
            select first 1
                    dsc.change_id
                    , dsc.sql_text
                from dbmon_structure_changelog as dsc
                where dsc.db_name is not distinct from :db_name
                    and dsc.object_type is not distinct from :object_type
                    and dsc.object_name is not distinct from :object_name
                    and dsc.change_type = :CHANGE_TYPE_BY_CREATE_STMT
                order by checked desc
                into prev_change_id, prev_create_statement;

            if (prev_create_statement is distinct from create_statement) then
            begin
                insert into dbmon_structure_changelog
                    (db_name, object_type, object_name, change_type, changed, checked, sql_text)
                values (:db_name, :object_type, :object_name, :CHANGE_TYPE_BY_CREATE_STMT, :checked, :checked, :create_statement);
            end
            else
            begin
                update dbmon_structure_changelog as dsc
                    set dsc.checked = :checked
                    where dsc.change_id = :prev_change_id;
            end
        end
    end
end^

set term ; ^