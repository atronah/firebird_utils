set term ^ ;

create or alter procedure aux_json_parse(
    json_in blob sub_type text
    , init_pos bigint = null
    , root_name varchar(1024) = null
    , root_node_index bigint = null
)

returns(
    node_start bigint
    , node_end bigint
    , value_start bigint
    , value_end bigint
    , node_path varchar(4096)
    , node_index bigint
    , value_type varchar(8)
    , name varchar(1024)
    , val blob sub_type text
    , json blob sub_type text
    , json_length bigint
    , level bigint
    , error_code bigint
    , error_text varchar(1024)
)
as
declare state smallint;
declare is_escaped_symbol smallint;
declare string_value blob sub_type text;
declare string_value_buffer varchar(255);
declare string_value_buffer_len smallint = 255;
declare pos bigint;
declare c varchar(1);
declare child_node_index bigint;
declare root_node_start bigint;
declare root_node_end bigint;
declare root_value_start bigint;
declare root_value_end bigint;
declare root_node_path varchar(4096);
declare root_value_type varchar(8);
declare root_val blob sub_type text;
declare temp_root_val varchar(16000);
declare is_sub_root smallint;
-- Constants
-- -- special symbols
declare SPACE varchar(1);
declare HRZ_TAB varchar(1);
declare NEW_LINE varchar(1);
declare CARR_RET varchar(1);
-- -- states
declare NO_STATE smallint = 0;
declare IN_OBJECT smallint = 1;
declare IN_STRING smallint = 2;
declare AFTER_STRING smallint = 3;
declare IN_ARRAY smallint = 4;
declare IN_NUMBER smallint = 5;
declare FINISH smallint = 6;
-- -- types of node
declare OBJ varchar(8) = 'object';
declare ARR varchar(8) = 'array';
declare STR varchar(8) = 'string';
declare NUM varchar(8) = 'number';
declare VALUE_TRUE varchar(8) = 'true';
declare VALUE_FALSE varchar(8) = 'false';
declare VALUE_NULL varchar(8) = 'null';
-- -- Flags
declare HAS_DOT smallint = 0;
declare ALREADY_SUSPENDED smallint = 0;
declare is_comma_required smallint = 0;
-- -- Errors
declare NO_ERROR bigint = 0;
declare UNEXPECTED_WHITESPACE_ERROR bigint = 1;
declare UNEXPECTED_NODE_ERROR bigint = 2;
declare UNEXPECTED_SYMBOL_IN_OBJECT_ERR bigint = 3;
declare UNEXPECTED_SYMBOL_IN_ARRAY_ERR bigint = 4;
declare UNEXPECTED_SYMBOL_AFTER_STR_ERR bigint = 5;
declare UNEXPECTED_SYMBOL_IN_NUMBER_ERR bigint = 6;
declare COMMA_MISSED_ERROR bigint = 7;
-- root_node_start
-- root_node_end
begin
    SPACE = ASCII_CHAR(32);
    HRZ_TAB = ASCII_CHAR(9);
    NEW_LINE = ASCII_CHAR(10);
    CARR_RET = ASCII_CHAR(13);

    error_code = NO_ERROR;
    error_text = null;

    is_comma_required = 0;

    state = NO_STATE;
    json = json_in;
    json_length = char_length(json);

    -- parameters of root/main/top json object in passed json_in,
    -- this parameters will be returned at the end of parsing after returning all child json objects
    root_node_start = null;
    root_node_end = null;
    root_value_start = null;
    root_value_end = null;
    root_node_index = coalesce(root_node_index, 0);
    root_value_type = null;
    root_val = '';
    temp_root_val = '';

    pos = coalesce(init_pos - 1, 0);
    while (pos < json_length
            and error_code = NO_ERROR
            and state is distinct from FINISH) do
    begin
        pos = pos + 1;
        c = substring(json from pos for 1);

        if (c in (SPACE, HRZ_TAB, NEW_LINE, CARR_RET) and state is distinct from IN_STRING) then
        begin
            if (state in (NO_STATE, AFTER_STRING, IN_OBJECT, IN_ARRAY)) then
            begin
                -- do nothing, skip
            end
            else if (state = IN_NUMBER) then
            begin
                state = FINISH;
            end
            else error_code = UNEXPECTED_WHITESPACE_ERROR;
        end
        else
        begin
            if (state = NO_STATE) then
            begin
                if (c = '{') then state = IN_OBJECT;
                else if (c = '[') then state = IN_ARRAY;
                else if (c = '"') then
                begin
                    state = IN_STRING;
                    string_value = '';
                    string_value_buffer = '';
                    is_escaped_symbol = 0;
                end
                else if (c = '-' and substring(json from pos + 1 for 1) in ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9')
                            or c in ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9')
                    ) then
                begin
                    state = IN_NUMBER; root_node_end = pos;
                end
                else if (c = left(VALUE_TRUE, 1)
                            and substring(json from pos for char_length(VALUE_TRUE)) = VALUE_TRUE) then
                begin
                    root_val = VALUE_TRUE;
                    state = FINISH; root_node_end = pos + char_length(VALUE_TRUE) - 1;
                    root_value_type = VALUE_TRUE;
                end
                else if (c = left(VALUE_FALSE, 1)
                            and substring(json from pos for char_length(VALUE_FALSE)) = VALUE_FALSE) then
                begin
                    root_val = VALUE_FALSE;
                    state = FINISH; root_node_end = pos + char_length(VALUE_FALSE) - 1;
                    root_value_type = VALUE_FALSE;
                end
                else if (c = left(VALUE_NULL, 1)
                        and substring(json from pos for char_length(VALUE_NULL)) = VALUE_NULL) then
                begin
                    root_val = VALUE_NULL;
                    state = FINISH; root_node_end = pos + char_length(VALUE_NULL) - 1;
                    root_value_type = VALUE_NULL;
                end
                else error_code = UNEXPECTED_NODE_ERROR;

                if (error_code = NO_ERROR) then
                begin
                    root_node_start = pos;
                    root_value_start = pos;
                    child_node_index = 0;
                    root_value_type = coalesce(root_value_type
                                                , case
                                                        when c = '{' then OBJ
                                                        when c = '[' then ARR
                                                        when c = '"' then STR
                                                        else NUM
                                                    end);
                end
            end
            else if (state = IN_OBJECT) then
            begin
                if (c = '}') then
                begin
                    state = FINISH; root_node_end = pos; root_value_end = pos;
                end
                else if (c = '"') then
                begin
                    if (is_comma_required > 0) then error_code = COMMA_MISSED_ERROR;
                    if (error_code <> NO_ERROR) then break;

                    for select
                            node_start, node_end, value_start, value_end, node_path, node_index, value_type, name, val, error_code, error_text, level
                        from aux_json_parse(:json, :pos, null, :child_node_index)
                        into node_start, node_end, value_start, value_end, node_path, node_index, value_type, name, val, error_code, error_text, level
                    do
                    begin
                        node_path = '/' || coalesce(nullif(root_name, ''), '-') || node_path;
                        if (error_code <> NO_ERROR) then break;
                        pos = node_end;
                        root_value_end = node_end;
                        level = level + 1;
                        suspend;
                    end
                    is_comma_required = 1;
                end
                else if (c = ',') then
                begin
                    is_comma_required = 0;
                    child_node_index = child_node_index + 1;
                end
                else error_code = UNEXPECTED_SYMBOL_IN_OBJECT_ERR;
            end
            else if (state = IN_ARRAY) then
            begin
                if (c = ']') then
                begin
                    state = FINISH; root_node_end = pos; root_value_end = pos;
                end
                else if (c in ('{', '"', '-', 't', 'f', 'n', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9')) then
                begin
                    if (is_comma_required > 0) then error_code = COMMA_MISSED_ERROR;
                    if (error_code <> NO_ERROR) then break;

                    for select
                            node_start, node_end, value_start, value_end, node_path, node_index, value_type, name, val, error_code, error_text, level
                        from aux_json_parse(:json, :pos, null, :child_node_index)
                        into node_start, node_end, value_start, value_end, node_path, node_index, value_type, name, val, error_code, error_text, level
                    do
                    begin
                        if (error_code <> NO_ERROR) then break;
                        node_path = '/' || coalesce(nullif(root_name, ''), '-') || node_path;
                        pos = node_end;
                        root_value_end = node_end;
                        level = level + 1;
                        suspend;
                    end
                    is_comma_required = 1;
                end
                else if (c = ',') then
                begin
                    is_comma_required = 0;
                    child_node_index = child_node_index + 1;
                end
                else error_code = UNEXPECTED_SYMBOL_IN_ARRAY_ERR;
            end
            else if (state = IN_STRING) then
            begin
                if (c = trim('\ ') and is_escaped_symbol = 0) then
                begin
                    is_escaped_symbol = 1;
                end
                else if (c = '"' and is_escaped_symbol = 0) then
                begin
                    state = AFTER_STRING;
                    root_node_end = pos;
                    root_value_end = pos;
                end
                else
                begin
                    root_value_start = coalesce(root_value_start, pos);

                    if (is_escaped_symbol > 0) then
                    begin
                        if (c = 't') then c = HRZ_TAB; -- tab
                        if (c = 'n') then c = NEW_LINE; -- new line
                        if (c = 'r') then c = CARR_RET; -- carriage return
                    end

                    if (char_length(string_value_buffer) >= string_value_buffer_len) then
                    begin
                        string_value = string_value || string_value_buffer;
                        string_value_buffer = '';
                    end
                    string_value_buffer = string_value_buffer || c;

                    is_escaped_symbol = 0;
                end
            end
            else if (state = AFTER_STRING) then
            begin
                if (c = ':') then
                begin
                    root_name = string_value || string_value_buffer;
                    string_value = ''; string_value_buffer = '';
                    root_value_start = null; root_value_end = null;
                    for select
                            node_start, node_end, value_start, value_end, node_path, node_index, value_type, name, val, error_code, error_text, level
                        from aux_json_parse(:json, :pos + 1, :root_name)
                        into node_start, node_end, value_start, value_end, node_path, node_index, value_type, name, val, error_code, error_text, level
                    do
                    begin
                        if (error_code <> NO_ERROR) then break;
                        root_value_start = coalesce(root_value_start, node_start);
                        pos = node_end;

                        -- for `"x": {...} ` is `{...}`
                        if (level = 0) then
                        begin
                            root_value_start = node_start;
                            root_value_end = node_end;
                            root_value_type = value_type;
                            if (value_type = STR)
                                then string_value = val;
                        end
                        else suspend;
                    end
                    state = FINISH; root_node_end = pos;
                end
                else if (c in ('"', '{', '[', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '-')) then error_code = COMMA_MISSED_ERROR;
                else if (c in (',', ']', '}')) then
                begin
                    state = FINISH;
                end
                else error_code = UNEXPECTED_SYMBOL_AFTER_STR_ERR;
            end
            else if (state = IN_NUMBER) then
            begin
                if (c in (',', ']', '}')) then
                begin
                    state = FINISH;
                    root_value_type = NUM;
                end
                else if (c in ('.', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9')) then
                begin
                    if (c = '.' and HAS_DOT > 0) then error_code = 5;
                    else
                    begin
                        if (c = '.') then HAS_DOT = 1;
                        root_value_end = pos;
                        root_node_end = pos;
                    end
                end
                else error_code = UNEXPECTED_SYMBOL_IN_NUMBER_ERR;
            end
        end
    end

    if (error_code <> NO_ERROR) then
    begin
        error_text = coalesce(error_text
                                , decode(error_code
                                        , UNEXPECTED_WHITESPACE_ERROR, 'Unexpected whitespace. '
                                        , UNEXPECTED_NODE_ERROR, 'Unexpected node start symbol. '
                                        , UNEXPECTED_SYMBOL_IN_OBJECT_ERR, 'Unexpected symbol inside object value. '
                                        , UNEXPECTED_SYMBOL_IN_ARRAY_ERR, 'Unexpected symbol inside array value. '
                                        , UNEXPECTED_SYMBOL_AFTER_STR_ERR, 'Unexpected symbol after string value. '
                                        , UNEXPECTED_SYMBOL_IN_NUMBER_ERR, 'Unexpected symbol in number value.'
                                        , COMMA_MISSED_ERROR, 'Missed comma. '
                                        , 'Unknown error code' || coalesce(error_code, 'null') || '. ')
                                || 'c: "' || coalesce(c, 'null') || '", pos: "'
                                || coalesce(pos, 'null') || '", state: "'
                                || coalesce(state, 'null') || '", near text (-4, +4): "'
                                || substring(json from maxvalue(0, pos - 4) for 8));
        suspend;
    end
    else if (state in (FINISH, AFTER_STRING, IN_NUMBER)) then
    begin
        node_start = root_node_start;
        node_end = root_node_end;
        value_start = coalesce(root_value_start, node_start);
        value_end = coalesce(root_value_end, node_end);
        value_type = root_value_type;
        level = 0;
        name = root_name;
        node_path = '/';
        val = iif(value_type = STR
                    , string_value || string_value_buffer
                    , substring(json from value_start for value_end - value_start + 1)
                );
        node_index = coalesce(root_node_index, 0);
        suspend;
    end

    when any do
    begin
        error_code = 99;
        error_text = 'Unknown dbms error. '
                    || 'c: "' || coalesce(c, 'null') || '", pos: "'
                    || coalesce(pos, 'null') || '", state: "'
                    || coalesce(state, 'null') || '", near text (-4, +4): "'
                    || substring(json from maxvalue(1, pos - 4) for 8);
        suspend;
    end
end^

set term ; ^

comment on procedure aux_json_parse is 'Parses all nodes from source JSON including nested';
comment on parameter aux_json_parse.json_in is 'Source JSON for parsing';
comment on parameter aux_json_parse.init_pos is 'Position in source JSON from which the parsing will be (for nested parsing)';
comment on parameter aux_json_parse.root_name is 'Name of node passed as source JSON  (for nested parsing)';
comment on parameter aux_json_parse.root_node_index is 'Index of parsed node in the parent node (for nested parsing)';
