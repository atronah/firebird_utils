set term ^ ;
create or alter trigger dbmon_before_any_ddl_statement
    active
    before ANY DDL STATEMENT
as
declare prev_unified_create_statement type of column dbmon_structure_changelog.prev_unified_create_statement;
begin
    if ((select val from dbmon_settings where key = 'log_prev_unified_create_statement') > 0) then
    begin
        if (exists(select rdb$procedure_name
                    from rdb$procedures
                    where rdb$package_name is null
                        and rdb$procedure_name = upper('aux_get_create_statement'))
        ) then
        begin
            execute statement ('select stmt from aux_get_create_statement(:object_name, :object_type)')
                (object_name := rdb$get_context('DDL_TRIGGER', 'OBJECT_NAME')
                , object_type := rdb$get_context('DDL_TRIGGER', 'OBJECT_TYPE'))
                into prev_unified_create_statement;
        end
        else
        begin
            insert into dbmon_structure_changelog (change_id, change_type, change_comment)
                values (1, 'error'
                        , 'Procedure aux_get_create_statement doesn''t exists in database.'
                        || ' Settings log_prev_unified_create_statement has ben disabled'
                        ||'; SQLCODE=' || coalesce(SQLCODE, 'null')
                        ||'; GDSCODE=' || coalesce(GDSCODE, 'null')
                        ||'; SQLSTATE=' || coalesce(SQLSTATE, 'null')
                        );
            update dbmon_settings set val = 0 where key = 'log_prev_unified_create_statement';
        end


        when any do
        begin
            insert into dbmon_structure_changelog (change_id, change_type, change_comment)
                values (1, 'error'
                        , 'Exception during uring computing prev_unified_create_statement'
                        ||'; SQLCODE=' || coalesce(SQLCODE, 'null')
                        ||'; GDSCODE=' || coalesce(GDSCODE, 'null')
                        ||'; SQLSTATE=' || coalesce(SQLSTATE, 'null')
                        );
        end
    end

    insert into dbmon_structure_changelog
            (object_name
                , object_type
                , change_type
                , old_object_name, new_object_name
                , sql_text
                , prev_unified_create_statement)
        values (rdb$get_context('DDL_TRIGGER', 'OBJECT_NAME')
                , rdb$get_context('DDL_TRIGGER', 'OBJECT_TYPE')
                , rdb$get_context('DDL_TRIGGER', 'EVENT_TYPE')
                , rdb$get_context('DDL_TRIGGER', 'OLD_OBJECT_NAME')
                , rdb$get_context('DDL_TRIGGER', 'NEW_OBJECT_NAME')
                , rdb$get_context('DDL_TRIGGER', 'SQL_TEXT')
                , :prev_unified_create_statement);

    when any do
    begin
        update or insert into dbmon_structure_changelog (change_id, change_type, change_comment)
            values (1, 'error'
                    , 'SQLCODE=' || coalesce(SQLCODE, 'null')
                    ||'; GDSCODE=' || coalesce(GDSCODE, 'null')
                    ||'; SQLSTATE=' || coalesce(SQLSTATE, 'null')
                    );
    end
end^

set term ; ^

comment on trigger dbmon_before_any_ddl_statement is 'DDL-trigger to track changes in database structure.
See https://github.com/atronah/firebird_utils/tree/master/dbmon for details.';