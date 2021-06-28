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
    , is_root smallint
    , error_code bigint
    , error_text varchar(1024)
)
as
declare state smallint;
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
declare PARAM varchar(8) = 'param';
declare NUM varchar(8) = 'number';
declare VALUE_TRUE varchar(8) = 'true';
declare VALUE_FALSE varchar(8) = 'false';
declare VALUE_NULL varchar(8) = 'null';
-- -- Flags
declare HAS_DOT smallint = 0;
declare ALREADY_SUSPENDED smallint = 0;
-- root_node_start
-- root_node_end
begin
    SPACE = ASCII_CHAR(32);
    HRZ_TAB = ASCII_CHAR(9);
    NEW_LINE = ASCII_CHAR(10);
    CARR_RET = ASCII_CHAR(13);

    error_code = 0;
    error_text = null;

    is_root = 0;

    state = NO_STATE;
    json = json_in;
    json_length = char_length(json);

    root_node_start = null;
    root_node_end = null;
    root_value_start = null;
    root_value_end = null;
    root_node_index = coalesce(root_node_index, 0);
    root_value_type = null;
    root_name = coalesce(root_name, '');
    root_val = '';
    temp_root_val = '';

    pos = coalesce(init_pos - 1, 0);
    while (pos < json_length
            and error_code = 0
            and state is distinct from FINISH) do
    begin
        pos = pos + 1;
        c = substring(json from pos for 1);

        if (c in (SPACE, HRZ_TAB, NEW_LINE, CARR_RET)) then
        begin
            if (state in (NO_STATE, AFTER_STRING, IN_OBJECT, IN_ARRAY)) then
            begin
                -- do nothing, skip
            end
            else if (state in (IN_STRING)) then
            begin
                root_value_end = pos;
            end
            else if (state = IN_NUMBER) then
            begin
                state = FINISH;
            end
            else error_code = 1;
        end
        else
        begin
            if (state = NO_STATE) then
            begin
                if (c = '{') then state = IN_OBJECT;
                else if (c = '[') then state = IN_ARRAY;
                else if (c = '"') then state = IN_STRING;
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
                end
                else if (c = left(VALUE_NULL, 1)
                        and substring(json from pos for char_length(VALUE_NULL)) = VALUE_NULL) then
                begin
                    root_val = VALUE_NULL;
                    state = FINISH; root_node_end = pos + char_length(VALUE_NULL) - 1;
                    root_value_type = VALUE_NULL;
                end
                else error_code = 2;

                if (error_code = 0) then
                begin
                    root_node_start = pos;
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
                    state = FINISH; root_node_end = pos;
                end
                else if (c = '"') then
                begin
                    if (error_code > 0) then break;

                    root_value_start = coalesce(root_value_start, pos);

                    for select
                            node_start, node_end, value_start, value_end, node_path, node_index, value_type, name, val, error_code, error_text
                        from aux_json_parse(:json, :pos, null, :child_node_index)
                        into node_start, node_end, value_start, value_end, node_path, node_index, value_type, name, val, error_code, error_text
                    do
                    begin
                        -- node_path = coalesce(nullif(trim(root_node_path || coalesce(root_name, '')), '') || '.', '') || node_path;
                        node_path = '/' || coalesce(nullif(root_name, ''), '-') || node_path;
                        if (error_code > 0) then break;
                        pos = node_end;
                        root_value_end = node_end;
                        suspend;
                    end
                end
                else if (c = ',') then
                begin
                    child_node_index = child_node_index + 1;
                end
                else error_code = 3;
            end
            else if (state = IN_ARRAY) then
            begin
                if (c = ']') then
                begin
                    state = FINISH; root_node_end = pos;
                end
                else if (c in ('{', '"', '-', 't', 'f', 'n', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9')) then
                begin
                    if (error_code > 0) then break;

                    root_value_start = coalesce(root_value_start, pos);

                    for select
                            node_start, node_end, value_start, value_end, node_path, node_index, value_type, name, val, error_code, error_text
                        from aux_json_parse(:json, :pos, null, :child_node_index)
                        into node_start, node_end, value_start, value_end, node_path, node_index, value_type, name, val, error_code, error_text
                    do
                    begin
                        if (error_code > 0) then break;
                        node_path = '/' || coalesce(nullif(root_name, ''), '-') || node_path;
                        pos = node_end;
                        root_value_end = node_end;
                        suspend;
                    end
                end
                else if (c = ',') then
                begin
                    child_node_index = child_node_index + 1;
                    root_value_end = pos;
                end
                else error_code = 4;
            end
            else if (state = IN_STRING) then
            begin
                if (c = '"') then
                begin
                    state = AFTER_STRING;
                    root_node_end = pos;
                end
                -- todo: add support escaped symbols including `\"`
                else
                begin
                    root_value_start = coalesce(root_value_start, pos);
                    root_value_end = pos;
                end
            end
            else if (state = AFTER_STRING) then
            begin
                if (c = ':') then
                begin
                    root_name = substring(json from root_value_start for root_value_end - root_value_start + 1);
                    root_value_start = null; root_value_end = null;
                    for select
                            node_start, node_end, value_start, value_end, node_path, node_index, value_type, name, val, error_code, error_text, is_root
                        from aux_json_parse(:json, :pos + 1, :root_name)
                        into node_start, node_end, value_start, value_end, node_path, node_index, value_type, name, val, error_code, error_text, is_sub_root
                    do
                    begin
                        if (error_code > 0) then break;
                        root_value_start = coalesce(root_value_start, value_start);
                        root_value_end = coalesce(value_end, node_end);
                        pos = node_end;

                        if (is_sub_root > 0) then
                        begin
                            root_value_start = value_start;
                            root_value_end = value_end;
                            root_value_type = value_type;
                        end
                        else suspend;
                    end
                    state = FINISH; root_node_end = pos;
                end
                else if (c in (',', ']', '}')) then
                begin
                    state = FINISH;
                    -- root_node_end = pos - 1;
                end
                else error_code = 5;
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
                else error_code = 6;
            end
        end
    end

    is_root = 1;
    if (error_code > 0) then
    begin
        error_text = coalesce(error_text
                                , 'c: "' || coalesce(c, 'null') || '", pos: "'
                                || coalesce(pos, 'null') || '", state: "'
                                || coalesce(state, 'null') || '"');
        suspend;
    end
    else if (state in (FINISH, AFTER_STRING, IN_NUMBER)) then
    begin
        node_start = root_node_start;
        node_end = root_node_end;
        value_start = coalesce(root_value_start, node_start);
        value_end = coalesce(root_value_end, node_end);
        value_type = root_value_type;
        name = nullif(root_name, '');
        node_path = '/';
        val = substring(json from value_start for value_end - value_start + 1);
        node_index = coalesce(root_node_index, 0);
        suspend;
    end
end^

set term ; ^