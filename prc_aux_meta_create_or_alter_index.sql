set term ^ ;

create or alter procedure aux_meta_create_or_alter_index(
    index_name type of column rdb$indices.rdb$index_name
    , index_table type of column rdb$indices.rdb$relation_name
    , index_expression type of column rdb$indices.rdb$expression_source
    , index_unique  type of column rdb$indices.rdb$unique_flag = null
    , index_descending type of column rdb$indices.rdb$index_type = null
    , force_create smallint = null
)
as
declare create_stmt blob sub_type text;
declare index_fields_list varchar(4096);
declare is_computed smallint;

declare is_exists_same_name smallint;

declare field_name type of column rdb$relation_fields.rdb$field_name;

declare current_fields_list varchar(4096);
declare current_table_name type of column rdb$indices.rdb$relation_name;
declare current_unique type of column rdb$indices.rdb$unique_flag;
declare current_descending type of column rdb$indices.rdb$index_type;
declare current_expression type of column rdb$indices.rdb$expression_source;
declare current_segment_count type of column rdb$indices.rdb$segment_count;

declare other_index_name type of column rdb$indices.rdb$index_name;
declare other_field_position type of column rdb$index_segments.rdb$field_position;
declare other_unique type of column rdb$indices.rdb$unique_flag;
declare other_descending type of column rdb$indices.rdb$index_type;
declare other_expression type of column rdb$indices.rdb$expression_source;
declare other_segment_count type of column rdb$indices.rdb$segment_count;
declare other_fields_list varchar(4096);
begin
    force_create = coalesce(force_create, 0);

    -- check existing of all fields from index expression
    -- and make ordered list of field names to check if an update of existed index is needed
    -- (if fields list changes by content or order)
    is_computed = 0;
    index_fields_list = null;
    for select
            rf.rdb$field_name as field_name
        from aux_split_text(:index_expression, ',') as p
            left join rdb$relation_fields as rf on rf.rdb$relation_name = upper(trim(:index_table))
                                                    and rf.rdb$field_name = upper(trim(p.part))
        order by p.idx
        into field_name
    do
    begin
        -- if field does not exists in the table
        -- assume it's `computed by (<expression>)` index insted of index by field list
        if (field_name is null) then
        begin
            is_computed = 1;
            index_fields_list = null;
            break;
        end
        index_fields_list = trim(coalesce(index_fields_list || ',', '')) ||  trim(upper(field_name));
    end

    create_stmt = 'create'
                    || ' ' || trim(iif(coalesce(index_unique, 0) > 0, 'unique', ''))
                    || ' ' || trim(iif(coalesce(index_descending, 0) > 0, 'desc', ''))
                    || ' index ' || index_name
                    || ' on ' || index_table
                    || ' ' || trim(iif(is_computed > 0, 'computed by', ''))
                    || ' (' || index_expression || ')';

    -- Try to find index with the same name to compare its params with new params
    is_exists_same_name = 0;
    current_fields_list = null;
    for select
            trim(upper(ind.rdb$relation_name)) as current_table_name
            , ind.rdb$unique_flag as current_unique
            , coalesce(ind.rdb$index_type, 0) as current_descending
            , ind.rdb$expression_source as current_expression
            , ind.rdb$segment_count as current_segment_count
            , seg.rdb$field_name as field_name
        from rdb$indices as ind
            left join rdb$index_segments as seg using(rdb$index_name)
        where ind.rdb$index_name = upper(:index_name)
            and coalesce(ind.rdb$system_flag, 0) = 0
        order by seg.rdb$field_position
        into current_table_name, current_unique, current_descending, current_expression, current_segment_count, field_name
    do
    begin
        is_exists_same_name = 1;
        current_fields_list = trim(coalesce(current_fields_list || ',', '')) ||  trim(upper(field_name));
    end

    -- stop processing, if index with the same name and same params is already exists
    if (is_exists_same_name > 0
        and trim(upper(current_table_name)) is not distinct from trim(upper(index_table))
        and coalesce(current_unique, 0) = coalesce(index_unique, 0)
        and coalesce(current_descending, 0) = coalesce(index_descending, 0)
        and trim(upper(current_expression)) is not distinct from '(' || trim(upper(index_expression)) || ')'
        and trim(upper(current_fields_list)) is not distinct from trim(upper(index_fields_list))
    ) then exit;

    -- stop processing, if exists different index with the same name
    -- but force creating (by drop previous version of index) is disabled
    if (is_exists_same_name > 0 and force_create = 0)
        then exit;

    -- Try to find other the same indecies on the same table with different name
    for select
            ind.rdb$index_name
            , ind.rdb$unique_flag as other_unique
            , coalesce(ind.rdb$index_type, 0) as other_descending
            , ind.rdb$expression_source as other_expression
            , ind.rdb$segment_count as other_segment_count
        from rdb$indices as ind
        where ind.rdb$relation_name = upper(:index_table)
            and coalesce(ind.rdb$system_flag, 0) = 0
        into other_index_name, other_unique, other_descending, other_expression, other_segment_count
    do
    begin
        if (coalesce(other_unique, 0) = coalesce(index_unique, 0)
            and coalesce(other_descending, 0) = coalesce(index_descending, 0)
            and coalesce(other_segment_count, 0) = coalesce(current_segment_count, 0)
        ) then
        begin
            -- compare fields list with adding index if expression is different
            if (trim(upper(other_expression)) is distinct from '(' || trim(upper(index_expression)) || ')') then
            begin
                if (other_segment_count > 0) then
                begin
                    other_fields_list = null;

                    for select
                            seg.rdb$field_name as field_name
                        from rdb$index_segments as seg
                        where seg.rdb$index_name = trim(upper(:other_index_name))
                        order by seg.rdb$field_position
                        into field_name
                    do
                    begin
                        other_fields_list = trim(coalesce(other_fields_list || ',', '')) ||  trim(upper(field_name));
                    end

                    -- stop processing, if fiels list the same
                    if (trim(upper(other_fields_list)) is not distinct from trim(upper(index_fields_list)))
                        then exit;
                end
            end
            --- stop processing, other index has the same unique and ascending and expression
            else exit;
        end
    end

    if (is_exists_same_name > 0)
        then execute statement 'drop index ' || index_name;

    execute statement create_stmt;
end^

set term ; ^

comment on procedure aux_meta_create_or_alter_index is 'Create or update index. Do nothing, if index with the same params (with the same or different name) is already exists';

comment on parameter aux_meta_create_or_alter_index.index_name is 'Name of index';
comment on parameter aux_meta_create_or_alter_index.index_table is 'Name of related table for index';
comment on parameter aux_meta_create_or_alter_index.index_expression is 'Field name or list of field name or index expression for index';
comment on parameter aux_meta_create_or_alter_index.index_unique is 'Create unique index if this param is more than 0. By default is 0 (non-unique index).';
comment on parameter aux_meta_create_or_alter_index.index_descending is 'Create descending index if this param is more than 0. By default is 0 (ascending index).';
comment on parameter aux_meta_create_or_alter_index.force_create is 'Drop existed index with the same name before creating new one if this param is more than 0. By default is 0 (skip creating if there is index with the same name).';
