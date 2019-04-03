execute block
returns(
    table_name varchar(31)
    , field_name varchar(31)
    , result_count bigint
)
as
declare search_id bigint;
begin
    search_id = ;
    
    for select 
            trim(rc.rdb$relation_name) as table_name
            , trim(idxs.rdb$field_name) as field_name
        from rdb$relation_constraints as rc
            inner join rdb$indices as idx on idx.rdb$index_name = rc.rdb$index_name
            inner join rdb$index_segments as idxs on idxs.rdb$index_name = idx.rdb$index_name
            inner join rdb$relation_fields as rf on rf.rdb$relation_name = rc.rdb$relation_name 
                                                        and rf.rdb$field_name = idxs.rdb$field_name
            inner join rdb$fields as f on f.rdb$field_name = rdb$field_source
        where rdb$constraint_type = 'PRIMARY KEY'
            and rdb$field_type in (7, 8, 16) -- 7 - smallint, 8 - integer, 16 - bigint
        into table_name, field_name
    do
    begin
        execute statement 'select count(*) from ' || table_name || ' where ' || field_name || ' = ' || search_id into result_count;
        if (result_count > 0) then suspend;
    end
end