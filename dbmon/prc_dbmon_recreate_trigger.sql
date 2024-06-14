set term ^ ;
create or alter procedure dbmon_recreate_trigger(
    table_name_filter type of column dbmon_tracked_field.table_name = null
    , work_mode smallint = null
)
returns (
    table_name type of column dbmon_tracked_field.table_name
    , create_trigger_statement tblob
    , primary_keys_block tblob
    , primary_key_fields type of column dbmon_data_changelog.primary_key_fields
)
as
declare field_name type of column dbmon_tracked_field.field_name;
declare field_description type of column rdb$relation_fields.rdb$description;
declare extra_cond type of column dbmon_tracked_field.extra_cond;
declare idx bigint;
begin
    work_mode = coalesce(work_mode, 0);

    for select distinct
            upper(trim(tf.table_name))
        from dbmon_tracked_field as tf
        where tf.table_name = coalesce(:table_name_filter, tf.table_name)
        into table_name
    do
    begin
        create_trigger_statement = '';
        for select distinct
                upper(trim(rdb$field_name))
                , tf.extra_cond
                , left(rf.rdb$description, 255) as field_description
            from dbmon_tracked_field as tf
                inner join rdb$relation_fields as rf on rf.rdb$relation_name = upper(tf.table_name)
                                                        and (rf.rdb$field_name = upper(tf.field_name)
                                                                or tf.field_name = '*')
            into field_name, extra_cond, field_description
        do
        begin
            create_trigger_statement = create_trigger_statement || '
                    -- ' || field_name || trim(coalesce(' - ' || field_description, '')) || '
                    if (new.' || field_name || ' is distinct from old.' || field_name
                    || iif(extra_cond > '', ' and (' || extra_cond || ')', '')
                    || ' and exists(select * from dbmon_tracked_field where table_name = '''
                            || table_name || ''' and field_name in (''' || field_name || ''', ''*'', ''?'') and coalesce(enabled, 0) = 1
                            and '','' || exclude_roles || '','' not like ''%,'' || current_role || '',%'')'
                    || ') then
                    begin
                        is_unknown_field_mark = 0;
                        insert into dbmon_data_changelog
                                (table_name, primary_key_1, primary_key_2, primary_key_3, primary_key_fields
                                , change_type, changed_field_name, old_value, new_value)
                        values (:table_name, :primary_key_1, :primary_key_2, :primary_key_3, :primary_key_fields
                                , :change_type, ''' || field_name || '''
                                , left(old.' || field_name || ', 4096), left(new.' || field_name || ', 4096));
                    end
                ';
        end

        primary_keys_block = '';
        primary_key_fields = '';
        for select
                trim(idxs.rdb$field_name) as field_name
                , idxs.rdb$field_position as idx
            from rdb$relation_constraints as c
                inner join rdb$indices as idx on idx.rdb$index_name = c.rdb$index_name
                inner join rdb$index_segments as idxs on idxs.rdb$index_name = idx.rdb$index_name
            where c.rdb$relation_name = :table_name
                and c.rdb$constraint_type containing 'primary key'
            order by idxs.rdb$field_position
            into field_name, idx
        do
        begin
            primary_key_fields = primary_key_fields || field_name || ';';
            primary_keys_block = primary_keys_block || '
                    primary_key_' || trim(idx + 1) || ' = coalesce(new.' || field_name || ', old.' || field_name || ');
                    ';
        end
        primary_keys_block = primary_keys_block || '
                    primary_key_fields = ''' || primary_key_fields || ''';
                    ';

        if (create_trigger_statement > '') then
        begin
            create_trigger_statement = 'create or alter trigger dbmon_' || left(hash(table_name), 20) || '_auid
                active
                after update or insert or delete
                on ' || table_name || '
                as
                declare is_unknown_field_mark smallint;
                declare primary_key_fields smallint;
                declare table_name type of column dbmon_data_changelog.table_name;
                declare primary_key_1 type of column dbmon_data_changelog.primary_key_1;
                declare primary_key_2 type of column dbmon_data_changelog.primary_key_2;
                declare primary_key_3 type of column dbmon_data_changelog.primary_key_3;
                declare change_type type of column dbmon_data_changelog.change_type;
                begin
                    if (not exists(select * from dbmon_tracked_field where table_name = '''
                                    || table_name || ''' and coalesce(enabled, 0) = 1
                                    and '','' || exclude_roles || '','' not like ''%,'' || current_role || '',%'')
                    ) then exit;

                    table_name = ''' || table_name || ''';
                    ' || primary_keys_block || '

                    change_type = case
                            when INSERTING then ''INSERT''
                            when UPDATING then ''UPDATE''
                            when DELETING then ''DELETE''
                    end;
                    is_unknown_field_mark = 1;

                    '
                    || create_trigger_statement || '

                    if (is_unknown_field_mark > 0
                            and exists(select * from dbmon_tracked_field where table_name = '''
                                    || table_name || ''' and coalesce(enabled, 0) = 1
                                    and field_name in (''?'', ''*''))
                    ) then
                    begin
                        insert into dbmon_data_changelog
                                (table_name, primary_key_1, primary_key_2, primary_key_3, primary_key_fields, change_type, changed_field_name)
                        values (:table_name, :primary_key_1, :primary_key_2, :primary_key_3, :primary_key_fields, :change_type, ''?'');
                    end

                    when any do
                    begin
                        insert into dbmon_data_changelog
                                (table_name, change_type)
                        values (:table_name, ''ERROR'');
                    end
                end
                ';
        end

        if (work_mode = 0)
            then suspend;
        else if (work_mode = 1)
            then execute statement create_trigger_statement;
    end
end^

set term ; ^


comment on procedure dbmon_recreate_trigger is 'Procedure to recreate triggers for tracking changes in fields of table, specified in dbmon_tracked_field';

comment on parameter dbmon_recreate_trigger.table_name_filter is 'Table name to recreate triggers. If null, triggers will be recreated for all tables in dbmon_tracked_field';
comment on parameter dbmon_recreate_trigger.work_mode is 'Work mode: 0 (default) - suspend recreating statements to manual execute; 1 - execute recreating statements';