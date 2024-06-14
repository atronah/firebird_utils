set term ^ ;
create or alter trigger dbmon_before_any_ddl_statement
    active
    before ANY DDL STATEMENT
as
begin
    insert into dbmon_structure_changelog
            (object_name
                , object_type
                , change_type
                , old_object_name, new_object_name
                , sql_text)
        values (rdb$get_context('DDL_TRIGGER', 'OBJECT_NAME')
                , rdb$get_context('DDL_TRIGGER', 'OBJECT_TYPE')
                , rdb$get_context('DDL_TRIGGER', 'EVENT_TYPE')
                , rdb$get_context('DDL_TRIGGER', 'OLD_OBJECT_NAME')
                , rdb$get_context('DDL_TRIGGER', 'NEW_OBJECT_NAME')
                , rdb$get_context('DDL_TRIGGER', 'SQL_TEXT'));

    when any do
    begin
        insert into dbmon_structure_changelog (change_type) values ('error');
    end
end^

set term ; ^