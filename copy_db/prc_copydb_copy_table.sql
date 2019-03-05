set term ^ ;

create or alter procedure copydb_copy_table(
    table_name varchar(31)
    , db_path varchar(255)
    , db_user varchar(32)
    , db_password varchar(32)
    , reraise_exception smallint = 0
)
returns(
    error_code bigint
    , error_text varchar(1024)
    , total_records bigint
    , copied_records bigint
    , stmt blob sub_type text
)
as
declare field_name varchar(31);
declare declare_list blob sub_type text;
declare field_list blob sub_type text;
declare coloned_field_list blob sub_type text;
declare endl varchar(2)='
';
begin
    error_code = 0;
    error_text = '';

    declare_list = '';
    field_list = '';
    coloned_field_list = '';
    for select
            trim(f.rdb$field_name) as field_name
        from rdb$relation_fields as f
        where f.rdb$relation_name = :table_name
            and coalesce(rdb$system_flag, 0) = 0
        into field_name
    do
    begin
        declare_list = declare_list
            || 'declare ' || field_name || ' type of column ' || table_name || '.' || field_name || ';' || endl;
        field_list = field_list || ',' || field_name;
        coloned_field_list = coloned_field_list || ',:' || field_name;
    end
    field_list = substring(field_list from 2);
    coloned_field_list = substring(coloned_field_list from 2);


    stmt = '
execute block
returns (
    copydb$total_records bigint
    , copydb$copied_records bigint
    , copydb$error_code bigint
    , copydb$error_text varchar(1024)
)
as
{declare_list}
begin
    copydb$error_code = 0;
    copydb$error_text = '''';

    execute statement ''select count(*) from {table_name}''
        on external ''{db_path}'' as user ''{db_user}'' password ''{db_password}'' role null
        into copydb$total_records;

    copydb$copied_records = 0;
    for execute statement ''select {field_list} from {table_name}''
        on external ''{db_path}'' as user ''{db_user}'' password ''{db_password}'' role null
        into {field_list}
    do
    begin
        update or insert into {table_name} ({field_list}) values ({coloned_field_list});
        copydb$copied_records = copydb$copied_records + 1;
    end

    suspend;

    when any do
    begin
        copydb$error_code = 99;
        copydb$error_text = left(''GDSCODE='' || coalesce(GDSCODE, ''null'') || ''; SQLCODE'' ||  coalesce(SQLCODE, ''null'') || ''; SQLSTATE'' ||  coalesce(SQLSTATE, ''null'')
                                , 1024);
        suspend;
        ' || iif(reraise_exception > 0, 'EXCEPTION;', '') || '
    end
end';

    stmt = replace(stmt, '{declare_list}', declare_list);
    stmt = replace(stmt, '{field_list}', field_list);
    stmt = replace(stmt, '{table_name}', table_name);
    stmt = replace(stmt, '{coloned_field_list}', coloned_field_list);
    stmt = replace(stmt, '{db_path}', db_path);
    stmt = replace(stmt, '{db_user}', db_user);
    stmt = replace(stmt, '{db_password}', db_password);

    execute statement stmt into total_records, copied_records, error_code, error_text;

    suspend;

    when any do
    begin
        error_code = 99;
        error_text = left('GDSCODE=' || coalesce(GDSCODE, 'null') || '; SQLCODE' ||  coalesce(SQLCODE, 'null') || '; SQLSTATE' ||  coalesce(SQLSTATE, 'null')
                            , 1024);
        suspend;
        if (reraise_exception > 0) then EXCEPTION;
    end
end^

set term ; ^