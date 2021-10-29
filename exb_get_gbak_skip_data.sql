execute block
returns(
    skip_data varchar(4096)
)
as
declare stmt varchar(60);
declare cnt bigint;
declare table_name varchar(31);
declare ROWS_LIMIT bigint;
declare EXCLUDE_TABLE_NAMES varchar(4096);
begin
    skip_data = '';

    ROWS_LIMIT = 10000;
    EXCLUDE_TABLE_NAMES = '';

    for select
            r.rdb$relation_name
            -- , (select rc from get_count(r.rdb$relation_name))
        from rdb$relations r
        where coalesce(r.rdb$system_flag, 0) = 0
            and coalesce(rdb$relation_type, 0) = 0
            and ',' || upper(:EXCLUDE_TABLE_NAMES) || ',' not like '%,' || trim(r.rdb$relation_name) || ',%'
        order by 1
    into table_name do
    begin
        stmt = 'select count(*) from "' || table_name || '"';
        execute statement stmt into cnt;

        if (cnt > ROWS_LIMIT) then
        begin
            if ((char_length(skip_data) + char_length(trim(table_name))) > 4000)
                then break;

            skip_data = skip_data
                        || trim(iif(skip_data > '', '|', ''))
                        || trim(table_name);
        end
    end
    skip_data = '(' || skip_data || ')';
    suspend;
end
