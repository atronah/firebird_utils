create or alter procedure aux_prepare_hierarchy (
    table_name varchar(4096)
    , id_field varchar(1024)
    , name_field varchar(1024)
    , parent_id_field varchar(1024)
    , cond varchar(1024)
    , order_cond varchar(1024)
)
returns(
    depth bigint
    , code varchar(255)
    , name_prefix varchar(255)
    , name varchar(1024)
    , stack tblob
    , stack_len bigint
    , last_stack_item varchar(255)
    , order_index bigint
)
as
declare old_stack tblob;
declare stack_item varchar(255);
declare stack_item_idx bigint;
declare child_depth bigint;
declare child_code type of column mds_nterm_mo.code;
begin
    stack = '';
    stack_len = 0;
    order_index = 0;

    for execute statement '
        select
            ' || id_field || '
        from ' || table_name || '
        where ' || cond || '
        ' || order_cond || '
        '
        into code
    do
    begin
        stack = stack || '0:' || code || ascii_char(10);
        stack_len = stack_len + 1;
    end

    while (stack_len > 0) do
    begin
        old_stack = stack;
        stack = '';
        last_stack_item = null;
        for select idx, part
            from aux_split_text_blob(:old_stack, ascii_char(10))
            where idx <= :stack_len
            order by idx
            into stack_item_idx, stack_item
            do
        begin
            if (stack_item_idx < stack_len) then
            begin
                stack = stack || stack_item || ascii_char(10);
            end
            else last_stack_item = stack_item;
        end
        stack_len = stack_len - 1;

        depth = trim(substring(last_stack_item from 1 for position(':' in last_stack_item) - 1));
        code = trim(substring(last_stack_item from position(':' in last_stack_item) + 1));
        name = null;

        execute statement ('
            select
                ' || name_field || ' as name
            from ' || table_name || '
            where ' || id_field || ' = :code')
            (code := :code)
            into name;
        /* Конструкция ниже позволяет выводить элементы иерархической структуры в следующем виде:
            a0
            |_ a01
            |  |_ a011
            |  |  |_a0111
            |  |_ a012
            |_ a02
        */
        name_prefix = trim(rpad('', 3 * depth, '|  ')) || trim(iif(depth > 0, '_', ''));

        child_depth = depth + 1;

        for execute statement ('
            select
                ' || id_field || ' as code
            from ' || table_name || '
            where ' || parent_id_field || ' = :code
                and ' || id_field || ' is distinct from :code')
            (code := :code)
            into child_code
        do
        begin
            stack = stack || child_depth || ':' || child_code || ascii_char(10);
            stack_len = stack_len + 1;
        end

        order_index = order_index + 1;
        suspend;
    end
end


