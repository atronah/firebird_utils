set term ^ ;

-- Returns all child items of specified item with current_id (or each item of table)
create or alter procedure aux_get_children(
    table_name varchar(64) -- name of table in which the items are searched
    , id_field varchar(64) -- name of table field, wherein the item identifier is stored
    , parent_field varchar(64) -- name of table field, wherein the parent item identifier is stored
    , current_id varchar(64) = null -- current item identifier, for which children are searched (if null - childrean are searched for each element of table)
    , only_leaf smallint = 0 -- 0 - returns all results, 1 - returns only leaf items (without children)
    , base_level smallint = 0 -- number of base level which is considered relatively child level number
    , sort_expression varchar(255) = null
)
returns (
    id varchar(64) -- item identified
    , parent_id varchar(64) -- parent item identified
    , child_level smallint -- child level number
    , sort_order bigint
)
as
declare stmt blob sub_type text;
declare has_child smallint;
begin
    sort_order = 0;

    child_level = base_level;
    parent_field = coalesce(parent_field, 0);
    current_id = coalesce(current_id, 0);

    stmt = 'select
                ' || :id_field || ' as id,
                ' || :parent_field || ' as parent_id
            from ' || :table_name || '
            ' || iif(coalesce(sort_expression, '') > '', 'order by ' || sort_expression, '');
            where ' || parent_field || ' = :current_id


    for execute statement (stmt)(current_id := :current_id)
    into :id, :parent_id do
    begin
        -- show current item if only_leaf option is disabled
        if (only_leaf = 0) then
        begin
            suspend;
            sort_order = sort_order + 1;
        end

        has_child = 0;

        for select id, parent_id, child_level
            from aux_get_children(:table_name
                                    , :id_field
                                    , :parent_field
                                    , :id
                                    , :only_leaf
                                    , :base_level + 1
                                    , :sort_expression)
            into :id, :parent_id, :child_level do
            begin
                has_child = 1;

                suspend;
                sort_order = sort_order + 1;
            end
        -- restore level for current item
        child_level = base_level;
        -- show current item if it doesn't have children for enabled only_leaf option
        if (only_leaf <> 0 and has_child = 0) then
        begin
            suspend;
            sort_order = sort_order + 1;
        end
    end
end^

set term ; ^
