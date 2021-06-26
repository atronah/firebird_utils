set term ^ ;

create or alter procedure aux_json_parse(
    json_in blob sub_type text
    , init_pos bigint = 1
)
returns(
    start_pos bigint
    , end_pos bigint
    , node_path varchar(4096)
    , node_index bigint
    , node_type varchar(8)
    , node_name varchar(1024)
    , node_content blob sub_type text
    , json blob sub_type text
    , json_length bigint
    , error_code bigint
    , error_text varchar(1024)
)
as
declare state smallint;
declare pos bigint;
declare c varchar(1);
declare main_start_pos bigint;
declare main_end_pos bigint;
declare main_node_path varchar(4096);
declare main_node_type varchar(8);
declare main_node_name varchar(255);
declare main_node_content blob sub_type text;
declare temp_main_node_content varchar(16000);
-- Constants
-- -- special symbols
declare SPACE varchar(1);
declare HRZ_TAB varchar(1);
declare NEW_LINE varchar(1);
declare CARR_RET varchar(1);
-- -- states
declare NO_STATE smallint = 0;
declare IN_OBJECT smallint = 1;
declare IN_NAME_STRING smallint = 2;
declare AFTER_STRING smallint = 3;
declare BEFORE_VALUE smallint = 4;
declare IN_VALUE_STRING smallint = 5;
declare IN_ARRAY smallint = 6;
declare IN_NUMBER smallint = 7;
declare FINISH smallint = 8;
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
-- main_start_pos
-- main_end_pos
begin
    SPACE = ASCII_CHAR(32);
    HRZ_TAB = ASCII_CHAR(9);
    NEW_LINE = ASCII_CHAR(10);
    CARR_RET = ASCII_CHAR(13);

    error_code = 0;
    error_text = null;

    state = NO_STATE;
    json = json_in;
    json_length = char_length(json);

    main_start_pos = null;
    main_end_pos = null;
    main_node_path = '/';
    main_node_type = null;
    main_node_name = '';
    main_node_content = '';
    temp_main_node_content = '';

    pos = init_pos;
    while (pos <= json_length and error_code = 0 and state is distinct from FINISH) do
    begin
        c = substring(json from pos for 1);

        if (c in (SPACE, HRZ_TAB, NEW_LINE, CARR_RET)) then
        begin
            if (state in (NO_STATE, AFTER_STRING, BEFORE_VALUE)) then
            begin
                -- do nothing, skip
            end
            else if (state in (IN_OBJECT, IN_OBJECT, IN_VALUE_STRING)) then
            begin
                if (char_length(temp_main_node_content) = 16000) then
                begin
                    main_node_content = main_node_content || temp_main_node_content;
                    temp_main_node_content = '';
                end
                temp_main_node_content = temp_main_node_content || c;
            end
            else if (state in (IN_NAME_STRING)) then
            begin
                main_node_name = main_node_name || c;
            end
            else if (state = IN_NUMBER) then
            begin
                state = FINISH;
                main_end_pos = pos - 1;
            end
            else error_code = 1;
        end
        else
        begin
            if (state = NO_STATE) then
            begin
                if (c = '{') then state = IN_OBJECT;
                else if (c = '[') then state = IN_ARRAY;
                else if (c = '"') then state = IN_VALUE_STRING;
                else if (c = '-' and substring(json from pos + 1 for 1) in (0, 1, 2, 3, 4, 5, 6, 7, 8, 9)
                            or c in (0, 1, 2, 3, 4, 5, 6, 7, 8, 9)
                    ) then
                begin
                    state = IN_NUMBER;
                    main_node_content = c;
                end
                else if (c = left(VALUE_TRUE, 1)
                            and substring(json from pos for char_length(VALUE_TRUE)) = VALUE_TRUE) then
                begin
                    main_node_content = VALUE_TRUE;
                    state = FINISH; main_end_pos = pos + char_length(VALUE_TRUE) - 1;
                    main_node_type = VALUE_TRUE;
                end
                else if (c = left(VALUE_FALSE, 1)
                            and substring(json from pos for char_length(VALUE_FALSE)) = VALUE_FALSE) then
                begin
                    main_node_content = VALUE_FALSE;
                    state = FINISH; main_end_pos = pos + char_length(VALUE_FALSE) - 1;

                end
                else if (c = left(VALUE_NULL, 1)
                        and substring(json from pos for char_length(VALUE_NULL)) = VALUE_NULL) then
                begin
                    main_node_content = VALUE_NULL;
                    state = FINISH; main_end_pos = pos + char_length(VALUE_NULL) - 1;
                    main_node_type = VALUE_NULL;
                end
                else error_code = 2;

                if (error_code = 0) then
                begin
                    main_start_pos = pos;
                    node_index = 0;
                    main_node_type = coalesce(main_node_type
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
                    state = FINISH; main_end_pos = pos;
                end
                else if (c = '"') then
                begin
                    if (error_code > 0) then break;

                    for select
                            start_pos, end_pos, node_path, node_type, node_name, node_content, error_code, error_text
                        from aux_json_parse(:json, :pos)
                        into start_pos, end_pos, node_path, node_type, node_name, node_content, error_code, error_text
                    do
                    begin
                        if (error_code > 0) then break;
                        node_path = main_node_path
                            || node_name;
                        pos = end_pos + 1;
                        suspend;
                        node_index = node_index + 1;
                    end
                end
                else if (c = ',') then
                begin
                    node_index = node_index + 1;
                end
                else error_code = 3;
            end
            else if (state = IN_ARRAY) then
            begin
                if (c = ']') then
                begin
                    state = FINISH; main_end_pos = pos;
                end
                else if (c in ('"', '-', 't', 'f', 'n', 0, 1, 2, 3, 4, 5, 6, 7, 8, 9)) then
                begin
                    if (error_code > 0) then break;

                    node_name = main_node_name;
                    for select
                            start_pos, end_pos, node_path, node_type, node_content, error_code, error_text
                        from aux_json_parse(:json, :pos)
                        into start_pos, end_pos, node_path, node_type, node_content, error_code, error_text
                    do
                    begin
                        if (error_code > 0) then break;
                        node_path = main_node_path || main_node_name
                            || node_path;
                        pos = end_pos + 1;
                        suspend;
                        node_index = node_index + 1;
                    end
                end
                else if (c = ',') then
                begin
                    node_index = node_index + 1;
                end
                else error_code = 3;
            end
            else if (state = IN_VALUE_STRING) then
            begin
                if (c = '"') then
                begin
                    state = AFTER_STRING;
                    main_node_type = coalesce(main_node_type, STR);
                    main_end_pos = pos;
                end
                -- todo: add support escaped symbols including `\"`
                else
                begin
                    if (char_length(temp_main_node_content) = 16000) then
                    begin
                        main_node_content = main_node_content || temp_main_node_content;
                        temp_main_node_content = '';
                    end
                    temp_main_node_content = temp_main_node_content || c;
                end
            end
            else if (state = AFTER_STRING) then
            begin
                if (c = ':') then
                begin
                    main_node_name = main_node_content || temp_main_node_content;
                    main_node_content = '';
                    temp_main_node_content = '';
                    main_end_pos = null;
                    main_node_type = PARAM;
                    state = BEFORE_VALUE;
                end
                else if (c in (',', ']', '}')) then
                begin
                    state = FINISH;
                    main_end_pos = pos - 1;
                end
                else error_code = 4;
            end
            else if (state = BEFORE_VALUE) then
            begin
                if (c = '"') then state = IN_VALUE_STRING;
                else
                begin
                    if (error_code > 0) then break;

                    for select
                            start_pos, end_pos, node_path, node_type, node_content, node_index, error_code, error_text
                        from aux_json_parse(:json, :pos)
                        into start_pos, end_pos, node_path, node_type, node_content, node_index, error_code, error_text
                    do
                    begin
                        if (error_code > 0) then break;
                        node_path = main_node_path || main_node_name || node_path;
                        pos = end_pos + 1;
                        suspend;
                    end
                end
            end
            else if (state = IN_VALUE_STRING) then
            begin
                if (c = '"') then
                begin
                    state = FINISH;
                    main_end_pos = pos;
                    main_node_type = PARAM;
                end
                else
                begin
                    if (char_length(temp_main_node_content) = 16000) then
                    begin
                        main_node_content = main_node_content || temp_main_node_content;
                        temp_main_node_content = '';
                    end
                    temp_main_node_content = temp_main_node_content || c;
                end
            end
            else if (state = IN_NUMBER) then
            begin
                if (c in (',', ']', '}')) then
                begin
                    state = FINISH;
                    main_end_pos = pos - 1;
                    main_node_type = NUM;
                end
                else if (c in ('.', 0, 1, 2, 3, 4, 5, 6, 7, 8, 9)) then
                begin
                    if (c = '.' and HAS_DOT > 0) then error_code = 5;
                    else
                    begin
                        if (c = '.') then HAS_DOT = 1;

                        if (char_length(temp_main_node_content) = 16000) then
                        begin
                            main_node_content = main_node_content || temp_main_node_content;
                            temp_main_node_content = '';
                        end
                        temp_main_node_content = temp_main_node_content || c;
                    end
                end
                else error_code = 6;
            end
        end
        if (error_code = 0) then pos = pos + 1;
    end

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
        start_pos = main_start_pos;
        end_pos = main_end_pos;
        node_path = main_node_path || main_node_name;
        node_type = main_node_type;
        node_name = main_node_name;
        node_content = main_node_content || temp_main_node_content;
        node_index = coalesce(node_index, 0);
        suspend;
    end
end^

set term ; ^