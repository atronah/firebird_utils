execute block
as
declare dbmon_db varchar(255);
declare dbmon_db_user varchar(32);
declare dbmon_db_password varchar(32);
declare dbmon_db_role varchar(32);

declare db_name type of column dbmon_structure_changelog.db_name;
declare object_type type of column dbmon_structure_changelog.object_type;
declare object_name type of column dbmon_structure_changelog.object_name;
declare changed type of column dbmon_structure_changelog.changed;
declare checked type of column dbmon_structure_changelog.checked;
declare change_type type of column dbmon_structure_changelog.change_type;
declare sql_text type of column dbmon_structure_changelog.sql_text;
begin
    dbmon_db = '';
    dbmon_db_user = current_user;
    dbmon_db_password = '';
    dbmon_db_role = current_role;
    change_type = 'DBMON_CHECK_FOR_CHANGES';

    for execute statement '
        select
            db as db_name
            , obj_type as object_type
            , obj_name as object_name
            , changed
            , checked
            , create_statement as sql_text
        from dbmon_changes_history as old_table
        order by old_table.checked asc
        '
        on external dbmon_db as user dbmon_db_user password dbmon_db_password role dbmon_db_role
        into db_name
            , object_type, object_name
            , changed, checked
            , sql_text
    do
    begin
        if (not exists(select *
                        from dbmon_structure_changelog as new_table
                        where new_table.object_name is not distinct from :object_name
                                and new_table.object_type is not distinct from upper(:object_type)
                                and new_table.db_name is not distinct from coalesce(nullif(:db_name, ''), rdb$get_context('SYSTEM', 'DB_NAME'))
                                and new_table.change_type is not distinct from :change_type
                                and new_table.changed is not distinct from :changed)
        ) then
        begin
            insert into dbmon_structure_changelog
                        (db_name
                        , object_type, object_name
                        , changed, checked, change_type
                        , sql_text)
                values (:db_name
                        , :object_type, :object_name
                        , :changed, :checked, :change_type
                        , :sql_text);
        end
    end
end
