set term ^ ;

-- copies record (one or more) that satisfy the condition `record_cond` from table `table_name`
-- additional features:
-- - copying from one specified db to another
-- - replace value of some fields during copy
create or alter procedure mds_aux_copy_record(
    table_name varchar(31) -- name of table, whose record(-s) should be copied
    , record_cond varchar(1024) -- condition to find record(-s) in table
    , exclude_fields varchar(1024) -- list of fields to exclude from copying
    , field_replaces blob sub_type text = null -- rules of field values replacements (like `field_a=1,field_b='new text'`)
    , from_db varchar(255) = null -- source database connection string, if null - current_database
    , from_db_user varchar(32) = null -- source database user name
    , from_db_password varchar(32) = null -- source database user password
    , to_db varchar(255) = null -- target database connection string, if null - current_database
    , to_db_user varchar(32) = null -- target database user name
    , to_db_password varchar(32) = null -- target database user password
)
returns (
    error_code bigint
    , error_text varchar(1024)
)
as
declare field_name varchar(31);
declare field_type varchar(31);
declare replaced_value varchar(255);
declare declares blob sub_type text;
declare fields_list blob sub_type text;
declare values_fields_list blob sub_type text;
declare stmt blob sub_type text;
declare endl varchar(2) = '
';
begin
    error_code = 0;
    error_text = '';

    -- get record fields info to make parts of sql-statement
    for select
            trim(rf.rdb$field_name) as field_name
            , trim(iif(rf.rdb$field_source starts with 'RDB$'
                        , case trim(t.rdb$type_name)
                                when 'LONG' then iif(f.rdb$field_scale = 0, 'INTEGER', 'NUMERIC(8,' || abs(f.rdb$field_scale) || ')')
                                when 'VARYING' then 'VARCHAR(' || f.rdb$field_length || ')'
                                when 'SHORT' then 'SMALLINT'
                                when 'TEXT' then 'CHAR(' || f.rdb$field_length || ')'
                                when 'DOUBLE' then iif(f.rdb$field_scale = 0, 'DOUBLE PRECISION', 'NUMERIC(8,' || abs(f.rdb$field_scale) || ')')
                                when 'BLOB' then iif(f.rdb$field_sub_type = 1, 'BLOB SUB_TYPE TEXT', 'BLOB SUB_TYPE ' || f.rdb$field_sub_type)
                                else trim(t.rdb$type_name)
                            end
                        , rf.rdb$field_source
            )) as field_type
        from rdb$relation_fields as rf
            left join rdb$fields as f on rf.rdb$field_source = f.rdb$field_name
            left join rdb$types as t on t.rdb$field_name = 'RDB$FIELD_TYPE' and t.rdb$type = f.rdb$field_type
        where upper(rf.rdb$relation_name) = upper(:table_name)
            and trim(upper(rf.rdb$field_name)) not in (select upper(trim(part)) from aux_split_text(:exclude_fields))
        order by rf.rdb$field_position
        into field_name, field_type
    do
    begin
        -- make declare block
        declares = coalesce(declares, '') || 'declare ' || field_name || ' ' || field_type || ';' || endl;
        -- make list of field names
        fields_list = coalesce(fields_list, '') || field_name || ',';

        -- make list of values (field name prefixed by colon or value from `field_replaces`)
        replaced_value = null;
        select
                substring(part from position('=' in part) + 1) as replaced_value
            from aux_split_text(:field_replaces)
            where part containing '='
                and upper(trim(substring(part from 1 for position('=' in part) - 1))) = upper(:field_name)
            into replaced_value;
        values_fields_list = coalesce(values_fields_list, '')
            || iif(replaced_value is null, ':' || field_name, replaced_value) || ',';
    end

    -- remove extra commas
    fields_list = trim(both ',' from fields_list);
    values_fields_list = trim(both ',' from values_fields_list);

    if (coalesce(fields_list, '') = '') then
    begin
        error_code = 1;
        error_text = 'Fields for copying  ' || coalesce(table_name, 'NULL') || ' were not found in table (may be table does not exist)';
    end

    if (error_code = 0) then
    begin
        -- make statement to execute on `to_db`
        stmt = 'execute block
                as
                ' || declares ||'
                begin
                    for execute statement ''select ' || fields_list || ' from ' || table_name || ' where ' || record_cond || '''
                        ' || iif(from_db is not null
                                    ,  'on external ''' || from_db || '''
                                        as user ''' || from_db_user || '''  password ''' || from_db_password || ''' role current_role'
                                    , '') || '
                    into ' || fields_list || '
                    do
                    begin
                        insert into ' || table_name || ' (' || fields_list || ') values (' || values_fields_list || ');
                    end
                end';

        if (to_db is null)
            then execute statement stmt;
        else execute statement stmt
                on external to_db
                as user to_db_user password to_db_password role current_role;
    end

    suspend;
end^

set term ; ^