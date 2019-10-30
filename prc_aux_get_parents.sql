set term ^ ;

create or alter procedure aux_get_parents(
    table_name varchar(255)
    , id_field_name varchar(31)
    , parent_id_field_name varchar(31)
    , start_parent_id bigint
    , parent_info_field_name varchar(31) = null
    , depth_limit smallint = 100
    , extra_cond varchar(1024) = null
)
returns(
    parent_id bigint
    , parent_info varchar(1024)
    , parent_level bigint
)
as
declare next_parent_id bigint;
begin
    parent_level = 0;
    extra_cond = coalesce(extra_cond, '');
    
    
    while (start_parent_id is not null and parent_level < depth_limit) do
    begin
        parent_level = parent_level + 1;
        parent_id = null;
        execute statement
            ('select '
                    || id_field_name || ' as item_id'
                    || ', ' || coalesce(parent_info_field_name, 'null') || ' as info'
                    || ', ' || parent_id_field_name || ' as parent_id'
                || ' from ' || table_name
                || ' where ' || id_field_name || ' = ' || start_parent_id)
                        || iif(extra_cond <> ''
                                , ' and (' || extra_cond || ')'
                                , '')
        into parent_id, parent_info, start_parent_id;
        if (parent_id is null) then break;
        suspend;
    end
end^

set term ; ^