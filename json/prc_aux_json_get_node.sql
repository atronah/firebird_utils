set term ^ ;

create or alter procedure aux_json_get_node(
    json_in blob sub_type text
    , key_param varchar(1024) = null
    , key_value varchar(1024) = null
    , value_param varchar(1024) = null
)
returns(
    node blob sub_type text
    , node_value blob sub_type text
    , node_path varchar(4096)
    , node_index bigint
    , node_type varchar(8)
    , node_start bigint
    , node_end bigint
    , node_level bigint
    , node_name varchar(1024)
    , value_name varchar(1024)
    , value_type varchar(8)
    , val blob sub_type text
    , error_code bigint
    , error_text varchar(1024)
)
as
declare key_node_path varchar(4096);
declare key_node_start bigint;
declare key_node_end bigint;
declare key_node_level bigint;
declare prefix varchar(255);
declare suffix varchar(255);
begin
    for select
            node_path, node_index, node_start, node_end, name, value_type, val, level
        from aux_json_parse(:json_in)
        order by level desc
        into node_path, node_index, node_start, node_end, node_name, value_type, val, node_level
    do
    begin
        if (node_name = key_param and val = key_value) then
        begin
            key_node_path = node_path;
            key_node_start = node_start;
            key_node_end = node_end;
            key_node_level = node_level;

        end
        else if (key_node_start > node_start and key_node_end < node_end
                and node_level = key_node_level - 1
        ) then
        begin
            node_value = val; val = null;
            node_type = value_type; value_type = null;
            prefix = decode(node_type, 'string', '"', 'object', '{', 'array', '[', '');
            suffix = decode(node_type, 'string', '"', 'object', '}', 'array', ']', '');
            node = :prefix || :node_value || :suffix;

            value_name = null;
            for select name, value_type, val
                from aux_json_parse(:node)
                where name = :value_param
                into value_name, value_type, val
            do suspend;
            if (row_count = 0) then suspend;
        end
        if (key_node_level is not null and (node_level - key_node_level) > 1) then exit;
    end
end^

set term ; ^

comment on procedure aux_json_get_node is 'Looks for JSON node with specified content
(which contains patameter with name `key_param` and value `key_value`).

For example:
select * from aux_json_get_node(''{"resources": [{"type": "A", "value": "A value"}, {"type": "B", "value": "B value"}] }'', ''type'', ''B'', ''value'')
returns resource `{"type": "B", "value": "B value"}` and value of its parameter "value"';
comment on parameter aux_json_get_node.json_in is 'Source JSON for parsing';
comment on parameter aux_json_get_node.key_param is 'Name of a key parameter in the JSON object to be searched for';
comment on parameter aux_json_get_node.key_value is 'Value of a key parameter in the JSON object to be searched for';
comment on parameter aux_json_get_node.value_param is 'Name of parameter in the JSON object to be searched for whose value should be retrieved';