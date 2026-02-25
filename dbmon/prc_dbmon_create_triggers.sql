set term ^ ;
create or alter procedure dbmon_create_triggers(
    table_name_filter type of column dbmon_tracked_field.table_name = null
    , work_mode smallint = null
)
returns (
    count_of_created_triggers bigint
    , table_name type of column dbmon_tracked_field.table_name
    , trigger_name type of column rdb$triggers.rdb$trigger_name
    , create_trigger_statement tblob
    , primary_keys_block varchar(8000)
    , primary_key_fields type of column dbmon_data_changelog.primary_key_fields
    , generation_duration_in_ms bigint
)
as
declare stmt_part varchar(32000);
declare started timestamp;
declare finished timestamp;
declare field_name type of column dbmon_tracked_field.field_name;
declare field_description type of column rdb$relation_fields.rdb$description;
declare extra_cond type of column dbmon_tracked_field.extra_cond;
declare idx bigint;
declare available_name_legth bigint;
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master/dbmon

    table_name_filter = nullif(upper(trim(table_name_filter)), '');
    work_mode = coalesce(work_mode, 0);
    count_of_created_triggers = 0;

    for select distinct
            tf.table_name
        from dbmon_tracked_field as tf
        where tf.table_name = coalesce(:table_name_filter, tf.table_name)
        into table_name
    do
    begin
        table_name = upper(trim(replace(table_name, '''', '''''')));

        if (not exists(select r.rdb$relation_name
                        from rdb$relations as r
                        where r.rdb$relation_name = :table_name)
        ) then
        begin
            update dbmon_tracked_field as tf
                    set tf.update_track_triggers = 0
                        , tf.errors = 'Table with name' || coalesce('"' || :table_name || '"', 'null') || ' not found'
                where tf.table_name = :table_name;
            continue;
        end

        started = cast('now' as timestamp);

        trigger_name = dbmon_trigger_name(:table_name, 'auid');

        create_trigger_statement = '';
        stmt_part = '';
        for select distinct
                upper(trim(rdb$field_name))
                , tf.extra_cond
                , left(rf.rdb$description, 255) as field_description
            from dbmon_tracked_field as tf
                inner join rdb$relation_fields as rf on rf.rdb$relation_name = upper(tf.table_name)
                                                        and (rf.rdb$field_name = upper(tf.field_name)
                                                                or tf.field_name = '*')
            where tf.table_name = :table_name
            order by rf.rdb$field_position
            into field_name, extra_cond, field_description
        do
        begin
            if (char_length(stmt_part) > 16000) then
            begin
                create_trigger_statement = create_trigger_statement || stmt_part;
                stmt_part = '';
            end

            field_description = replace(field_description, ascii_char(10), '&#10;');
            field_description = replace(field_description, ascii_char(13), '&#13;');
            field_description = left(field_description, 255);

            stmt_part = stmt_part || '
    -- ' || field_name || trim(coalesce(' - ' || field_description, '')) || '
    if (new.' || field_name || ' is distinct from old.' || field_name
    || iif(extra_cond > '', ' and (' || extra_cond || ')', '')
    || ' and '','' || enabled_field_names || '','' like ''%,' || field_name || ',%'''
    || ') then
    begin
        is_unknown_field_mark = 0;
        insert into dbmon_data_changelog
                (table_name, primary_key_1, primary_key_2, primary_key_3, primary_key_fields
                , change_type, changed_field_name, old_value, new_value)
        values (:table_name, :primary_key_1, :primary_key_2, :primary_key_3, :primary_key_fields
                , :change_type, ''' || field_name || '''
                , left(old.' || field_name || ', 16000), left(new.' || field_name || ', 16000));
    end'
            ;
        end
        create_trigger_statement = create_trigger_statement || stmt_part;

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
            primary_keys_block = primary_keys_block
                                    || '    primary_key_' || trim(idx + 1) || ' = coalesce(new.' || field_name || ', old.' || field_name || ');'
                                    || ascii_char(10);
        end
        primary_keys_block = primary_keys_block
                            || '    primary_key_fields = ''' || primary_key_fields || ''';'
                            || ascii_char(10);

        if (create_trigger_statement > '') then
        begin
            create_trigger_statement = 'create or alter trigger ' || trigger_name || '
active
after update or insert or delete
on ' || table_name || '
as
declare is_unknown_field_mark smallint;
declare primary_key_fields type of column dbmon_data_changelog.primary_key_fields;
declare table_name type of column dbmon_data_changelog.table_name;
declare primary_key_1 type of column dbmon_data_changelog.primary_key_1;
declare primary_key_2 type of column dbmon_data_changelog.primary_key_2;
declare primary_key_3 type of column dbmon_data_changelog.primary_key_3;
declare change_type type of column dbmon_data_changelog.change_type;
declare enabled_field_names varchar(16384);
begin
    enabled_field_names = (select
                                list(distinct
                                    trim(coalesce(rdb$field_name
                                                    , iif(tf.field_name = ''?'', tf.field_name, null)))
                                )
                            from dbmon_tracked_field as tf
                                left join rdb$relation_fields as rf on rf.rdb$relation_name = tf.table_name
                                                                    and (rf.rdb$field_name = upper(tf.field_name)
                                                                            or tf.field_name = ''*'')
                            where tf.table_name = '''|| table_name || '''
                                and coalesce(tf.enabled, 0) = 1
                                and '','' || coalesce(tf.exclude_roles, '''') || '','' not like ''%,'' || current_role || '',%''
                            );
    if (coalesce(enabled_field_names, '''') = '''')
        then exit;

    table_name = ''' || table_name || ''';
    ' || primary_keys_block || '

    change_type = case
            when INSERTING then ''INSERT''
            when UPDATING then ''UPDATE''
            when DELETING then ''DELETE''
    end;

    is_unknown_field_mark = 1;
    ' || create_trigger_statement || '
    -- log fact of changes in table without specifying changed field names
    -- (that block uses if only rule with field_name=''?'' is enabled for table)
    if (is_unknown_field_mark > 0
            and '','' || enabled_field_names || '','' like ''%,?,%''
    ) then
    begin
        insert into dbmon_data_changelog
                (table_name, primary_key_1, primary_key_2, primary_key_3, primary_key_fields, change_type, changed_field_name)
        values (:table_name, :primary_key_1, :primary_key_2, :primary_key_3, :primary_key_fields, :change_type, ''?'');
    end

    when any do
    begin
        insert into dbmon_data_changelog
                (table_name, primary_key_1, primary_key_2, primary_key_3, primary_key_fields, change_type)
        values (:table_name, :primary_key_1, :primary_key_2, :primary_key_3, :primary_key_fields, ''ERROR'');
    end
end
';
        end
        finished = cast('now' as timestamp);
        generation_duration_in_ms = datediff(millisecond from started to finished);

        if (work_mode = 0) then
        begin
            create_trigger_statement = 'set term ^ ;' || ascii_char(13) || ascii_char(10)
                                        || nullif(create_trigger_statement, '') || '^'
                                        || ascii_char(13) || ascii_char(10)
                                        || 'set term ; ^';
            suspend;
        end
        else if (work_mode = 1 and create_trigger_statement > '')
            then execute statement create_trigger_statement;
    end

    if (work_mode = 0) then
    begin
        table_name = null;
        trigger_name = null;
        create_trigger_statement = null;
        primary_keys_block = null;
        primary_key_fields = null;
        suspend;
    end
end^

set term ; ^


comment on procedure dbmon_create_triggers is 'Procedure to (re)create triggers for tracking changes in fields of table, specified in dbmon_tracked_field';

comment on parameter dbmon_create_triggers.table_name_filter is 'Optional table name filter for tables that the triggers is to be (re)created for.
If not passed (passed `null`), triggers will be (re)created for all tables from dbmon_tracked_field';
comment on parameter dbmon_create_triggers.work_mode is 'Work mode: 0 (default) - suspend (re)create statements to manual execute; 1 - execute (re)create statements';
