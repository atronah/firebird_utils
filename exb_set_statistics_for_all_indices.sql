execute block
as
declare index_name type of column rdb$indices.rdb$index_name;
begin
    for select
            rdb$index_name
        from rdb$indices
        where coalesce(rdb$system_flag, 0) = 0
        into index_name
    do execute statement 'SET STATISTICS INDEX ' || index_name || ';';
end