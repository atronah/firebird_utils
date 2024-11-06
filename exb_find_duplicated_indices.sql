execute block
returns (
    table_name varchar(31) -- type of column rdb$indices.rdb$relation_name
    , index_name varchar(31) -- type of column rdb$indices.rdb$index_name
    , is_uniq type of column rdb$indices.rdb$unique_flag
    , is_inactive type of column rdb$indices.rdb$index_inactive
    , is_desc type of column rdb$indices.rdb$index_type
    , segment_count type of column rdb$indices.rdb$segment_count
    , fields_list varchar(1024)
    , index_statistics type of column rdb$index_segments.rdb$statistics

    , duplicate_found smallint
    , d_table_name varchar(31) -- type of column rdb$indices.rdb$relation_name
    , d_index_name varchar(31) -- type of column rdb$indices.rdb$index_name
    , d_is_uniq type of column rdb$indices.rdb$unique_flag
    , d_is_inactive type of column rdb$indices.rdb$index_inactive
    , d_is_desc type of column rdb$indices.rdb$index_type
    , d_segment_count type of column rdb$indices.rdb$segment_count
    , d_fields_list varchar(1024)
    , d_index_statistics type of column rdb$index_segments.rdb$statistics

    , full_duplicate_list varchar(4096)
    , duplicate_by_fields_list varchar(4096)

    , index_name_filter type of column rdb$indices.rdb$index_name
)
as
declare field_name type of column rdb$index_segments.rdb$field_name;
declare field_position type of column rdb$index_segments.rdb$field_position;
declare field_statistics type of column rdb$index_segments.rdb$statistics;
declare d_field_name type of column rdb$index_segments.rdb$field_name;
declare d_field_position type of column rdb$index_segments.rdb$field_position;
declare d_field_statistics type of column rdb$index_segments.rdb$statistics;
begin
    index_name_filter = null; -- optional filter to reduce list of processing indices (used as `like`-expression)

    -- lookup through all NON-system indices
    for select
            trim(i.rdb$relation_name) as table_name
            , trim(i.rdb$index_name) as index_name
            , coalesce(i.rdb$unique_flag, 0) as is_uniq
            , coalesce(i.rdb$index_inactive, 0) as is_inactive
            , coalesce(i.rdb$index_type, 0) as is_desc
            , i.rdb$segment_count as segment_count
            , iif(i.rdb$segment_count = 0, i.rdb$statistics, 0) as index_statistics
            , iif(i.rdb$segment_count = 0, i.rdb$expression_source, null) as fields_list
        from rdb$indices as i
        where coalesce(i.rdb$system_flag, 0) = 0
            and (:index_name_filter is null or i.rdb$index_name like :index_name_filter)
        into table_name, index_name, is_uniq, is_inactive, is_desc
            , segment_count, index_statistics, fields_list
    do
    begin
        -- if index based on fields (no on expression)
        -- make index field lists in right order
        for select
                s.rdb$field_name, s.rdb$statistics, s.rdb$field_position
            from rdb$index_segments as s
            where s.rdb$index_name = :index_name
            order by s.rdb$field_position asc
            into field_name, field_statistics, field_position
        do
        begin
            index_statistics = index_statistics + field_statistics;
            fields_list = trim(coalesce(fields_list || ',', '') || trim(field_name));
        end

        -- if index based on fields (no on expression) - calculate index statistics as an arithmetic mean
        -- WARN: I am not sure, that `arithmetic mean` is a correct algoritm to get index statistics
        if (segment_count > 0)
            then index_statistics = index_statistics / segment_count;

        duplicate_found = 0;
        -- lookup through all NON-system other indices on the same table
        for select
                trim(i.rdb$relation_name) as d_table_name
                , trim(i.rdb$index_name) as d_index_name
                , coalesce(i.rdb$unique_flag, 0) as d_is_uniq
                , coalesce(i.rdb$index_inactive, 0) as d_is_inactive
                , coalesce(i.rdb$index_type, 0) as d_is_desc
                , i.rdb$segment_count as segment_count
                , iif(i.rdb$segment_count = 0, i.rdb$statistics, 0) as d_index_statistics
                , iif(i.rdb$segment_count = 0, i.rdb$expression_source, null) as d_fields_list
            from rdb$indices as i
            where i.rdb$relation_name = :table_name
                and i.rdb$index_name is distinct from :index_name
            into d_table_name, d_index_name, d_is_uniq, d_is_inactive, d_is_desc
                , d_segment_count, d_index_statistics, d_fields_list
        do
        begin
            -- if other index based on fields (no on expression)
            -- make other index field lists in right order
            for select
                    s.rdb$field_name, s.rdb$statistics, s.rdb$field_position
                from rdb$index_segments as s
                where s.rdb$index_name = :d_index_name
                order by s.rdb$field_position asc
                into d_field_name, d_field_statistics, d_field_position
            do
            begin
                d_index_statistics = d_index_statistics + d_field_statistics;
                d_fields_list = trim(coalesce(d_fields_list || ',', '') || trim(d_field_name));
            end

            -- if other index based on fields (no on expression) - calculate other index statistics as an arithmetic mean
            -- WARN: I am not sure, that `arithmetic mean` is a correct algoritm to get index statistics
            if (d_segment_count > 0)
                then d_index_statistics = d_index_statistics / d_segment_count;

            -- if other index selectivity worse
            if (d_index_statistics >= index_statistics
                and fields_list = d_fields_list -- and field list of index and other index is equal
                -- and fields_list starts with d_fields_list -- and field list of index and other index has common beginning
                and is_uniq = d_is_uniq -- uniq mark of index and other index is the same
                and is_desc = d_is_desc -- order of index and other index is the same
            ) then
            begin
                duplicate_found = 1;
                suspend; -- show duplicate indices
            end
        end

        if (duplicate_found = 0) then
        begin
            d_table_name = null; d_index_name = null; d_is_uniq = null; d_is_inactive = null;
            d_is_desc = null; d_fields_list = null; d_index_statistics = null;
            -- suspend; -- optional suspend all indicies even without duplicates
        end
    end
end