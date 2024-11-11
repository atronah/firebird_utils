execute block
returns(
    table_name varchar(31)
    , field_name varchar(31)
    , field_type_name varchar(31)
    , result_count bigint
)
as
declare search_field_type_list varchar(1024);
declare search_data varchar(64);
declare table_name_regex varchar(1024);
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    -- https://www.firebirdsql.org/file/documentation/html/en/refdocs/fblangref25/firebird-25-language-reference.html
    -- 7 - SMALLINT
    -- 8 - INTEGER
    -- 10 - FLOAT
    -- 12 - DATE
    -- 13 - TIME
    -- 14 - CHAR
    -- 16 - BIGINT
    -- 27 - DOUBLE PRECISION
    -- 35 - TIMESTAMP
    -- 37 - VARCHAR
    -- 40 - CSTRING (https://www.ibase.ru/types)
    -- 261 - BLOB
    search_field_type_list = '14,37,40';
    search_data = 'some text';
    table_name_regex = 'MY_TABLE_%';

    for select
            trim(r.rdb$relation_name) as table_name
            , trim(rf.rdb$field_name) as field_name
            -- https://www.programmersforum.ru/showpost.php?s=0a2bc680822319bbdc23db0caf045c17&p=1717168&postcount=2
            , trim(case f.rdb$field_type
                        when 7 then 'smallint'
                        when 8 then 'integer'
                        when 10 then 'float'
                        when 14 then 'char'
                        when 16 then -- только диалект 3
                            case f.rdb$field_sub_type
                                when 0 then 'bigint'
                                when 1 then 'numeric'
                                when 2 then 'decimal'
                                else 'unknown'
                            end
                        when 12 then 'date'
                        when 13 then 'time'
                        when 27 then -- только диалект 1
                            case f.rdb$field_scale
                                when 0 then 'double precision'
                                else 'numeric'
                            end
                        when 35 then 'date'  --или timestamp в зависимости от диалекта
                        when 37 then 'varchar'
                        when 261 then 'blob'
                        else 'unknown'
                    end
            ) as field_type_name
        from rdb$relations as r
            inner join rdb$relation_fields as rf on rf.rdb$relation_name = r.rdb$relation_name
            inner join rdb$fields as f on f.rdb$field_name = rdb$field_source
        where coalesce(r.rdb$system_flag, 0) = 0
            and (:table_name_regex is null or r.rdb$relation_name similar to :table_name_regex)
            and (',' || :search_field_type_list || ',') like ('%,' || rdb$field_type || ',%')
        into table_name, field_name, field_type_name
    do
    begin
        execute statement 'select count(*) from ' || table_name
                            || ' where ' || field_name
                            || ' = ' ||  iif(field_type_name in ('char', 'date', 'time', 'varchar')
                                            , '''' || replace(search_data, '''', '''''') || ''''
                                            , search_data)
                            into result_count;
        if (result_count > 0) then suspend;
    end
end