create or alter procedure aux_json_get_value(
    json blob sub_type text
    , node_name varchar(128)
)
returns (
        json_length bigint
        , node_pos bigint
        , value_type varchar(8)
        , value_block_pos bigint
        , value_block blob sub_type text
        , value_block_length bigint
        , val blob sub_type text
        , val_text4k varchar(4096)
        , val_int bigint
)
as
declare c varchar(1);
declare colon_pos bigint;
declare pos_offset bigint;
declare pos bigint;
declare point_pos bigint;
declare value_end_symbol varchar(1);
declare nested_blocks_stack varchar(1024);
begin
    node_name = trim(node_name);

    pos_offset = 1;
    json_length = char_length(json);

    node_pos = position('"' || node_name  || '"', json, pos_offset);
    while (node_pos > pos_offset) do
    begin
        -- check that found substring is node name (only colon can be after node name)
        colon_pos = null;
        value_pos = null;
        value_type = null;
        value_block_length = null;
        value_block = null;
        val = null;
        val_text4k = null;
        val_int = null;

        pos = node_pos + char_length('"' || node_name  || '"');
        while (pos < json_length) do
        begin
            c = substring(json from pos for 1);
            if (c = ':') then
            begin
                colon_pos = pos;
                break;
            end
            else if (c not in (' ', ASCII_CHAR(13), ASCII_CHAR(10)))
                then break;
            pos = pos + 1;
        end

        if (colon_pos is not null) then
        begin
            -- find value node start symbo
            -- - `"` for string-value,
            -- - `[` for list-value,
            -- - `{` for object-value
            -- - 0-9 for number-value )
            pos = colon_pos + 1;
            while (pos < json_length) do
            begin
                c = substring(json from pos for 1);
                if (c in ('{', '[', '"', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'))
                then
                begin
                    value_pos = pos;
                    value_type = trim(decode(c
                                            , '{', 'obj'
                                            , '[', 'lst'
                                            , '"', 'str'
                                            , 'num'));
                    break;
                end
                else if (c not in (' ', ASCII_CHAR(13), ASCII_CHAR(10)))
                then break;
                pos = pos + 1;
            end
        end

        if (value_type is not null) then
        begin
            if (value_type in ('obj', 'lst')) then
            begin
                nested_blocks_stack = '';
                value_end_symbol = decode(value_type
                                            , 'obj', '}'
                                            , 'lst', ']');
                pos = value_pos + 1;
                while (pos < json_length) do
                begin
                    c = substring(json from pos for 1);

                    if ('"{[' containing c) then
                    begin
                        -- detecting end of string (last open symbol in stack is quote)
                        if (c = '"' and right(nested_blocks_stack, 1) = '"') then
                        begin
                            nested_blocks_stack = left(nested_blocks_stack, char_length(nested_blocks_stack) - 1);
                        end
                        -- detecting new nested block
                        else nested_blocks_stack = nested_blocks_stack || c;
                    end

                    if (nested_blocks_stack <> '') then
                    begin
                        -- finishing nested block
                        if (c = decode(right(nested_blocks_stack, 1)
                                        , '{', '}'
                                        , '[', ']')
                        ) then nested_blocks_stack = left(nested_blocks_stack, char_length(nested_blocks_stack) - 1);
                    end
                    else if (c = value_end_symbol) then
                    begin
                        value_block_length = pos - value_pos + 1;
                        break;
                    end

                    pos = pos + 1;
                end
                -- not supported yet, because it requires handle nested objects
                -- with skipping closed symbols `}` and `]` inside string values
            end
            else if (value_type = 'num') then
            begin
                pos = value_pos;
                point_pos = null;
                value_block_length = 0;
                while (pos < json_length) do
                begin
                    c = substring(json from pos for 1);
                    if (c not in ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.')) then
                    begin
                        break;
                    end
                    else if (c = '.') then
                    begin
                        if (point_pos is not null) then
                        begin
                            value_block_length = null;
                            break;
                        end
                        else point_pos = pos;
                    end

                    value_block_length = value_block_length + 1;
                    pos = pos + 1;
                end
            end
            else if (value_type = 'str') then
            begin
                value_block_length = position('"', json, value_pos + 1) - value_pos + 1;
            end

            if (value_block_length is not null) then
            begin
                value_block = substring(json from value_pos for value_block_length);
                if (value_type = 'num') then
                begin
                    val = value_block;
                    if (val not containing '.')
                        then val_int = val;
                end
                else val = substring(value_block from 2 for value_block_length - 2);

                val_text4k = left(val, 4096);
            end

            suspend;
        end

        pos_offset = iif(value_block_length > 0, value_pos + value_block_length + 1, node_pos + 1);
        node_pos = position('"' || node_name  || '"', json, pos_offset);
    end
end