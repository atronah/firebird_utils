insert into dbmon_structure_changelog
        (db_name
            , object_type, object_name
            , changed, checked, change_type
            , sql_text
            )
    select
            db as db_name
            , obj_type as object_type
            , obj_name as object_name
            , changed
            , checked
            , 'DBMON_CHECK_FOR_CHANGES' as change_type
            , create_statement as sql_text
        from dbmon_changes_history as old_table
    where not exists (select *
                        from dbmon_structure_changelog as new_table
                        where new_table.object_name is not distinct from old_table.obj_name
                                and new_table.object_type is not distinct from upper(old_table.obj_type)
                                and new_table.db_name is not distinct from coalesce(nullif(old_table.db, ''), rdb$get_context('SYSTEM', 'DB_NAME'))
                                and new_table.change_type is not distinct from 'DBMON_CHECK_FOR_CHANGES'
                                and new_table.changed is not distinct from old_table.changed)
    order by old_table.checked asc
