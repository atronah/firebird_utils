insert into dbmon_structure_changelog (db_name, object_type, object_name, changed, checked, changes_type, sql_text)
    select
            db as db_name
            , obj_type as object_type
            , obj_name as object_name
            , changed
            , checked
            , 'AUX_GET_CREATE_STATEMENT' as changes_type
            , create_statement as sql_text
        from dbmon_changes_history as old_table
    where not exists (select *
                        from dbmon_structure_changelog as new_table
                        where new_table.object_name is not distinct from old_table.obj_name
                                and new_table.object_type is not distinct from upper(old_table.obj_type)
                                and new_table.db_name is not distinct from old_table.db
                                and new_table.changes_type is not distinct from 'AUX_GET_CREATE_STATEMENT'
                                and new_table.changed is not distinct from old_table.changed)
