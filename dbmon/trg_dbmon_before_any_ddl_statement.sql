set term ^ ;
create or alter trigger dbmon_before_any_ddl_statement
    active
    before ANY DDL STATEMENT
as
declare object_type type of column dbmon_structure_changelog.object_type;
declare object_name type of column dbmon_structure_changelog.object_name;
declare block_enabled type of column dbmon_block_stucture_changes.enabled;
declare block_comment type of column dbmon_block_stucture_changes.comment;
declare prev_unified_create_statement type of column dbmon_structure_changelog.prev_unified_create_statement;
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master/dbmon

    object_type = upper(trim(rdb$get_context('DDL_TRIGGER', 'OBJECT_TYPE')));
    object_name = upper(trim(rdb$get_context('DDL_TRIGGER', 'OBJECT_NAME')));

    select
            bsc.enabled, bsc.comment
        from dbmon_block_stucture_changes as bsc
        where bsc.object_type = :object_type
            and bsc.object_name = :object_name
        into block_enabled, block_comment;
    block_enabled = coalesce(block_enabled, 0);

    if (block_enabled is distinct from 0) then
    begin
        exception DBMON_CHANGES_NOT_ALLOWED coalesce(block_comment, '');
    end
    else
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
                    (object_name := :object_name
                    , object_type := :object_type)
                    into prev_unified_create_statement;
            end
            else
            begin
                insert into dbmon_structure_changelog
                    (object_name, object_type, change_type, change_comment)
                values (:object_name, :object_type, 'ERROR'
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
                insert into dbmon_structure_changelog
                    (object_name, object_type, change_type, change_comment)
                values (:object_name, :object_type, 'ERROR'
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
            values (:object_name
                    , :object_type
                    , rdb$get_context('DDL_TRIGGER', 'EVENT_TYPE')
                    , rdb$get_context('DDL_TRIGGER', 'OLD_OBJECT_NAME')
                    , rdb$get_context('DDL_TRIGGER', 'NEW_OBJECT_NAME')
                    , rdb$get_context('DDL_TRIGGER', 'SQL_TEXT')
                    , :prev_unified_create_statement);
    end
end^

set term ; ^

comment on trigger dbmon_before_any_ddl_statement is 'DDL-trigger to track changes in database structure.
See https://github.com/atronah/firebird_utils/tree/master/dbmon for details.';