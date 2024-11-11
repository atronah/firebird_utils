set term ^ ;

-- transform JSON to YAML
create or alter procedure aux_json_to_yaml(
    json_in blob sub_type text
)
returns (
    yaml blob sub_type text
    , error_code bigint
    , error_text varchar(1024)
)
as
declare node_name varchar(255);
declare current_indent varchar(64);
declare value_type varchar(32);
declare prev_value_type varchar(32);
declare parent_value_type varchar(32);
declare parent_type_stack varchar(4096);
declare val tblob;
declare level bigint;
declare prev_level bigint;
declare is_object_in_array smallint;
-- Constants
-- -- indent
declare BASE_INDENT varchar(64) = '                                                                '; -- 64 spaces as a max indent
-- -- other
declare ENDL varchar(2) = '
';
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    parent_value_type = null;
    parent_type_stack = null;
    is_object_in_array = 0;
    yaml = '';
    for select
            name, value_type, val, level, error_code, error_text
        from aux_json_parse(:json_in)
        order by node_start
        into node_name, value_type, val, level, error_code, error_text
    do
    begin
        if (error_code > 0)
            then break;
        -- when turned back to higher level
        -- delete from parent_type_stack all types which level lower or equal current
        while (prev_level > level) do
        begin
            parent_type_stack = substring(parent_type_stack from position('/' in parent_type_stack) + 1);
            prev_level = prev_level - 1;
        end
        parent_type_stack = iif(prev_level < level, prev_value_type || trim(coalesce('/' || parent_type_stack, '')), parent_type_stack);

        parent_value_type = (select part from aux_split_text(:parent_type_stack, '/') where idx = 1);

        -- no indent for first child of noname object-item in an array
        current_indent = iif(is_object_in_array = 0, left(base_indent, maxvalue(level - 1, 0) * 2), ' ');
        is_object_in_array = iif(parent_value_type = 'array' and value_type = 'object', 1, 0);

        yaml = yaml
            || current_indent
            || trim(iif(parent_value_type = 'array', '-', '')
                    || coalesce(' ' || node_name || ':', '')
                    || iif(val is not null and value_type in ('string', 'number', 'true', 'false', 'null')
                            , ' ' || iif(value_type = 'string', '"' || val || '"', val)
                            , '')
                    )
            -- no new line after beginning of an array with noname objects, like
            -- "list": [
            --     {"a": 1, "b": 2},
            --     {"a": 3, "b": 4}
            -- ]
            -- to get in result this yaml
            -- list
            --     - a: 1
            --       b: 1
            --     - a: 2
            --       b: 3
            -- (https://stackoverflow.com/questions/33989612/yaml-equivalent-of-array-of-objects-in-json)
            || iif(is_object_in_array = 0
                    and (node_name > ''
                            or parent_value_type = 'array'
                            or value_type in ('string', 'number', 'true', 'false', 'null') and val is not null)
                    , ENDL
                    , '');

        prev_value_type = value_type;
        prev_level = level;
    end

    suspend;
end^

set term ; ^

