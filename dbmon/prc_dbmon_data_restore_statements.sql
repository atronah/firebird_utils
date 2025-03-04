set term ^ ;

create or alter procedure dbmon_data_restore_statements(
    after_datetime timestamp
    , before_datetime timestamp
    , recover_table_name_list varchar(1024)
    , change_type_filter type of column dbmon_data_changelog.change_type = null
    , client_process_filter type of column dbmon_data_changelog.client_process = null
)
returns (
    restore_stmt varchar(16000)
    , restore_table_name type of column dbmon_data_changelog.table_name
    , restore_primary_key_1 type of column dbmon_data_changelog.primary_key_1
    , restore_primary_key_2 type of column dbmon_data_changelog.primary_key_2
    , restore_primary_key_3 type of column dbmon_data_changelog.primary_key_3
)
as
declare table_name type of column dbmon_data_changelog.table_name;
declare primary_key_1 type of column dbmon_data_changelog.primary_key_1;
declare primary_key_2 type of column dbmon_data_changelog.primary_key_2;
declare primary_key_3 type of column dbmon_data_changelog.primary_key_3;
declare change_type type of column dbmon_data_changelog.change_type;
declare primary_key_fields type of column dbmon_data_changelog.primary_key_fields;
declare changed_field_name type of column dbmon_data_changelog.changed_field_name;
declare old_value type of column dbmon_data_changelog.old_value;
declare new_value type of column dbmon_data_changelog.new_value;

declare update_base varchar(16000);
declare update_fields varchar(16000);
declare update_cond varchar(16000);
declare insert_base varchar(16000);
declare insert_fields varchar(16000);
declare insert_values varchar(16000);
declare prev_table_name type of column dbmon_data_changelog.table_name;
declare prev_primary_key_1 type of column dbmon_data_changelog.primary_key_1;
declare prev_primary_key_2 type of column dbmon_data_changelog.primary_key_2;
declare prev_primary_key_3 type of column dbmon_data_changelog.primary_key_3;
begin
    for select
            table_name, primary_key_1, primary_key_2, primary_key_3
            , change_type, primary_key_fields
            , changed_field_name, old_value, new_value
        from dbmon_data_changelog as dc
        where dc.changed between :after_datetime and :before_datetime
            and ',' || :recover_table_name_list || ',' like '%,' || dc.table_name || ',%'
            and (:client_process_filter is null
                    or dc.client_process containing :client_process_filter)
            and (:change_type_filter is null
                    or ',' || :change_type_filter || ',' like '%,' || dc.change_type || ',%')
        order by table_name, primary_key_1, primary_key_2, primary_key_3, change_id desc
        into table_name, primary_key_1, primary_key_2, primary_key_3
            , change_type, primary_key_fields
            , changed_field_name, old_value, new_value
    do
    begin
        if (table_name is distinct from prev_table_name
            or primary_key_1 is distinct from prev_primary_key_1
            or primary_key_2 is distinct from prev_primary_key_2
            or primary_key_3 is distinct from prev_primary_key_3
        ) then
        begin
            if (update_base > '' and update_fields > '' and update_cond > '')
                    then restore_stmt = update_base || update_fields || update_cond || ';';
            if (insert_base > '' and insert_fields > '' and insert_values > '')
                then restore_stmt = insert_base || '(' || insert_fields || ')' || ' values (' || insert_values || ');';

            if (restore_stmt > '') then
            begin
                restore_table_name = prev_table_name;
                restore_primary_key_1 = prev_primary_key_1;
                restore_primary_key_2 = prev_primary_key_2;
                restore_primary_key_3 = prev_primary_key_3;
                suspend;
            end

            restore_stmt = null;
            update_base = null; update_fields = null; update_cond = null;
            insert_base = null; insert_fields = null; insert_values = null;
            if (change_type = 'UPDATE') then
            begin
                update_base = 'update ' || table_name || ' set ';
                update_fields = (select part from aux_split_text(:primary_key_fields, ';') where idx = 1)
                                || ' = ' || (select part from aux_split_text(:primary_key_fields, ';') where idx = 1);
                update_cond = ' where '
                                || coalesce((select part from aux_split_text(:primary_key_fields, ';') where idx = 1)
                                            || ' = ''' || primary_key_1 || ''''
                                            , '')
                                || coalesce(' and '
                                            || (select part from aux_split_text(:primary_key_fields, ';') where idx = 2)
                                            || ' = ''' || primary_key_2 || ''''
                                            , '')
                                || coalesce(' and '
                                            || (select part from aux_split_text(:primary_key_fields, ';') where idx = 3)
                                            || ' = ''' || primary_key_3 || ''''
                                            , '');
            end
            else if (change_type = 'DELETE') then
            begin
                insert_base = 'insert into ' || table_name;
                insert_fields = coalesce((select part from aux_split_text(:primary_key_fields, ';') where idx = 1), '')
                                || coalesce(' , ' || (select part from aux_split_text(:primary_key_fields, ';') where idx = 2), '')
                                || coalesce(' , ' || (select part from aux_split_text(:primary_key_fields, ';') where idx = 3), '');

                insert_values = coalesce('''' || primary_key_1 || '''', '')
                                || coalesce(' , ''' || primary_key_2 || '''', '')
                                || coalesce(' , ''' || primary_key_3 || '''', '');
            end
            prev_table_name = table_name;
            prev_primary_key_1 = primary_key_1;
            prev_primary_key_2 = primary_key_2;
            prev_primary_key_3 = primary_key_3;
        end

        if (change_type = 'UPDATE') then
        begin
            update_fields = update_fields
                                || ', ' || changed_field_name
                                || ' = ' || coalesce('''' || replace(old_value, '''', '''''')|| '''', 'null')
                                || ' /* old: ' || coalesce(new_value, 'null') || '*/' ;
        end
        else if (change_type = 'DELETE') then
        begin
            if (';' || primary_key_fields || ';' not like '%;' || changed_field_name || ';%') then
            begin
                insert_fields = insert_fields|| ', ' || changed_field_name;
                insert_values = insert_values || ', ' || coalesce('''' || replace(old_value, '''', '''''') || '''', 'null');
            end
        end
    end

    if (update_base > '' and update_fields > '' and update_cond > '')
        then restore_stmt = update_base || update_fields || update_cond || ';';
    if (insert_base > '' and insert_fields > '' and insert_values > '')
        then restore_stmt = insert_base || '(' || insert_fields || ')' || ' values (' || insert_values || ');';

    if (restore_stmt > '') then
    begin
        restore_table_name = prev_table_name;
        restore_primary_key_1 = prev_primary_key_1;
        restore_primary_key_2 = prev_primary_key_2;
        restore_primary_key_3 = prev_primary_key_3;
        suspend;
    end
end