set term ^ ;

create or alter procedure aux_xml_get_value(
    xml_source blob sub_type text
    , node_name varchar(64)
    , vtype varchar(16) = null
    , req smallint = null
    , node_index smallint = null
    , check_nil_attribute smallint = null
)
returns (
    val blob sub_type text
    , val_int bigint
    , val_float float
    , val_double double precision
    , val_date date
    , val_time time
    , val_datetime timestamp
    , time_zone smallint
    , attributes blob sub_type text
    , node_number bigint
    , node_start bigint
    , node_end bigint
    , value_start bigint
    , value_end bigint
    , error_code smallint
    , error_text varchar(1024)
)
as
declare looking_start bigint;
declare after_node_name varchar(2);
declare tag_end bigint;
declare is_empty_tag smallint;
declare empty_tag_end bigint;
declare next_tag_start bigint;
declare nested_level bigint;
declare is_load_all_exists smallint;
declare pos bigint;
declare prev_node_start bigint;
-- Constants
declare NESTED_LIMIT smallint = 100;

-- -- -- -- -- -- -- -- -- -- --
-- --     sub-routines     -- --
-- -- -- -- -- -- -- -- -- -- --
declare procedure aux_raise_exception(
            error_code bigint
            , error_text varchar(1000)
        )
        as
        begin
            rdb$set_context('USER_TRANSACTION', 'AUX_EXCEPTION_ERROR_CODE', error_code);
            rdb$set_context('USER_TRANSACTION', 'AUX_EXCEPTION_ERROR_TEXT', error_text);
            -- create exception AUX_ERROR '';
            exception AUX_ERROR coalesce(error_code, 99) || ':' || trim(coalesce(error_text, 'Unknown error'));
        end
declare procedure aux_xml_get_node_start(
            xml_source blob sub_type text
            , node_name varchar(64)
            , node_index smallint = null
            , looking_start bigint = null
        )
        returns (
            node_start bigint
        )
        as
        declare name_length bigint;
        declare tmp_string varchar(2);
        declare tag_end bigint;
        declare empty_tag_end bigint;
        declare next_tag_start bigint;
        declare match_count bigint;
        begin
            node_index = coalesce(node_index, 1);
            looking_start = coalesce(looking_start, 1);

            if (coalesce(node_name, '') = '')
                then execute procedure aux_raise_exception(1, 'XML node name cannot be empty');


            name_length = char_length(node_name);
            node_index = maxvalue(1, node_index);
            match_count = 0;
            while (match_count < node_index) do
            begin
                node_start = coalesce(position('<' || node_name, xml_source, looking_start), 0);

                if (node_start = 0) then break;

                tmp_string = substring(xml_source
                                        from node_start + name_length + 1
                                        for 2);
                if (tmp_string = '/>'
                    or left(tmp_string, 1) in (' ', '>')
                    ) then match_count = match_count + 1;

                looking_start = node_start + name_length + 1;
            end

            suspend;
        end
-- -- -- -- -- -- -- -- -- -- --
-- -- end of sub-routines  -- --
-- -- -- -- -- -- -- -- -- -- --
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    vtype = coalesce(vtype, 'str');
    req = coalesce(req, 0);
    node_index = coalesce(node_index, 1);
    check_nil_attribute = coalesce(check_nil_attribute, 1);

    pos = 1;
    error_code = 0;
    error_text = '';

    vtype = lower(vtype);

    if (coalesce(node_name, '') = '')
        then execute procedure aux_raise_exception(1, 'XML node name cannot be empty');

    is_load_all_exists = 0;
    if(node_index is null) then
    begin
        is_load_all_exists = 1;
        node_index = 1;
    end

    node_number = node_index;

    node_start = 0;
    prev_node_start = null;
    while (node_start is distinct from prev_node_start) do
    begin
        -- reset values for next node
        val = null;
        val_int = null;
        val_float = null;
        val_double = null;
        val_date = null;
        val_time = null;
        val_datetime = null;
        time_zone = null;
        attributes = null;
        value_start = null;
        value_end = null;
        is_empty_tag = 0;

        -- save previous position to control progress
        prev_node_start = node_start;

        -- looking for start of next XML node
        select node_start from aux_xml_get_node_start(:xml_source, :node_name, :node_index, :pos) into node_start;
        -- get position just after node name, but before attributes of node
        looking_start = node_start + char_length(node_name) + 1;
        -- get 2 symbols after node name
        after_node_name = substring(xml_source from looking_start for 2);

        -- if no next node
        if (coalesce(node_start, 0) = 0) then
        begin
            -- raise exception for required nodes if no nodes were found
            if (req > 0 and node_number = 1)
                then execute procedure aux_raise_exception(2, left('Required XML node "'
                                                                        || coalesce(:node_name, '')
                                                                        || '" with oridnal number "'
                                                                        || coalesce(:node_number, '')
                                                                        || '" is not found', 1024));
            break;
        end
        -- returns emty value for empty node (like `<a />`)
        else if (after_node_name = '/>')
            then val = iif(vtype = 'node', null, '');
        else
        begin
            -- prepare first simbol after node name to check
            after_node_name = left(after_node_name, 1);

            -- processing node without attributes
            if (after_node_name = '>') then
            begin
                -- position of end of tag (of symbol `>`) is equal to looking_start (first symbol after node/tag name)
                tag_end = looking_start;
                value_start = tag_end + 1;
            end
            -- processing node without attributes (has space after node name)
            else if (after_node_name = ' ') then
            begin
                -- looking for position of closing symbol of open tag
                tag_end = position('>', xml_source, looking_start);
                -- check for empty tag (for example: `<a />`)
                empty_tag_end = position('/>', xml_source, looking_start);
                -- looking for position of open symbol of next tag
                next_tag_start = position('<', xml_source, looking_start);

                -- skip end of tag (`>`) if next tag starts before it (because it's an end of next tag)
                -- (I couldn't remember how it posible in correct XML during refactoring that code, but left that check)
                if (next_tag_start > 0 and next_tag_start < tag_end) then tag_end = 0;

                -- skip end of empty tag (`/>`) if next tag starts before it  (because it's an end of next tag)
                if (next_tag_start > 0 and next_tag_start < empty_tag_end) then empty_tag_end = 0;

                -- current node is empty if nearest end of empty tag (`/>`) found before nearest end of non empty tag (`/>`)
                if (empty_tag_end > 0 and (empty_tag_end < tag_end or tag_end = 0)) then
                begin
                    tag_end = empty_tag_end + 1;
                    is_empty_tag = 1;
                    val = iif(vtype = 'node', null, '');
                end
                -- otherwise, current node is not empty and next symbol after end of tag is a start of value
                else value_start = tag_end + 1;
            end

            -- if current node is not empty (found end of open tag)
            if (tag_end > 0) then
            begin
                -- getting attributes as text between tag name and end of tag
                attributes = trim(substring(xml_source
                                            from looking_start + 1
                                            for maxvalue(tag_end - looking_start - iif(is_empty_tag = 0, 1, 2), 0)));
                -- checking for `nil` attribute if it enabled by input parameter `check_nil_attribute`
                if (check_nil_attribute > 0
                    and attributes similar to '(%:|% |)nil[[:WHITESPACE:]]*=[[:WHITESPACE:]]*"true"%') then
                begin
                    val = null;
                    value_start = null;
                end
                -- getting value of node
                else if (value_start is not null) then
                begin
                    nested_level = 0;
                    looking_start = value_start;

                    value_end = position('</' || node_name || '>', xml_source, value_start + 1);

                    -- skip nested nodes with the same name
                    while (nested_level < NESTED_LIMIT) do
                    begin
                        -- get position of the next nearest node with the same name
                        -- (at the begining `next_similar = startpos`, but after found last nested node it becomes `0`)
                        if (looking_start > 0) then
                        begin
                            select node_start
                                from aux_xml_get_node_start(:xml_source, :node_name, 1, :looking_start)
                                into next_tag_start;
                        end

                        -- nested node with the same name has been found
                        if (next_tag_start > 0 and next_tag_start < value_end) then
                        begin
                            if (substring(:xml_source
                                        from position('>', :xml_source, :next_tag_start + 1) - 1
                                        for 2) = '/>'
                            ) then
                            begin
                                -- skip empty tag like `<tag/>
                                looking_start = next_tag_start + 1;
                            end
                            else
                            begin
                                nested_level = nested_level + 1;
                                looking_start = next_tag_start + 1;
                            end
                        end
                        else
                        begin
                            if (nested_level <= 0) then break;
                            -- looking for the end tag for the each nested tag until reach `nested_level = 0`
                            -- for the input xml `<a><a><a><a>x</a></a></a></a>` there will be the following steps:
                            -- - value_end = 14 -> 18, nested_level = 3 -> 2
                            -- - value_end = 18 -> 22, nested_level = 2 -> 1
                            -- - value_end = 22 -> 26, nested_level = 1 -> 0
                            value_end = position('</' || node_name || '>', xml_source, value_end + 1);
                            looking_start = 0; -- stop looking nested nodes
                            nested_level = nested_level - 1;
                        end
                    end

                    if (value_end = 0) then
                        execute procedure aux_raise_exception(3, left('Unable to find end of value for node "'
                                                                        || coalesce(:node_name, '')
                                                                        || '" (at position "'
                                                                        || coalesce(:node_start, '')
                                                                        || '" in source XML) with oridnal number "'
                                                                        || coalesce(:node_number, '')
                                                                        || '" ', 1000));

                    val = substring(xml_source from value_start for value_end - value_start);
                end
            end
            else execute procedure aux_raise_exception(4, left('Unable to find end of open tag for node "'
                                                                        || coalesce(:node_name, '')
                                                                        || '" (at position "'
                                                                        || coalesce(:node_start, '')
                                                                        || '" in source XML) with oridnal number "'
                                                                        || coalesce(:node_number, '')
                                                                        || '" ', 1000));
        end
        node_end = position('>', xml_source
                            , maxvalue(coalesce(value_end, 0)
                                        , coalesce(tag_end, 0)
                                        , coalesce(looking_start, 0)));
        node_end = maxvalue(coalesce(node_end, 0), node_start);

        pos = node_end + 1;
        -- after finding the first element, always search for the first one (taking into account the offset)
        node_index = 1;

        -- processing the received value according to the specified type
        select
                val_string, val_int, val_float, val_double, val_date, val_time, val_datetime
                , time_zone
                , error_code, error_text
            from aux_string_to_type(:val, :vtype)
            into val, val_int, val_float, val_double, val_date, val_time, val_datetime
                , time_zone
                , error_code, error_text;

        if (error_code > 0)
            then execute procedure aux_raise_exception(:error_code, left('Value "'
                                                                            || coalesce(:val, 'null')
                                                                            ||  '" of XML node "' || coalesce(:node_name, 'null')
                                                                            || '" is incorrect: ' || coalesce(:error_text, '')
                                                                            , 1000));

        suspend;

        if (is_load_all_exists = 0)
            then break;

        node_number = node_number + 1;
    end

    when any do
    begin
        error_code = coalesce(rdb$get_context('USER_TRANSACTION', 'AUX_EXCEPTION_ERROR_CODE'), 99);
        error_text = rdb$get_context('USER_TRANSACTION', 'AUX_EXCEPTION_ERROR_TEXT');

        -- suspend error info instead exception for not required or smooth required without exception
        if (req in (0, 1))
            then suspend;
        -- othewise re-raise exception
        else exception;
    end
end^

set term ; ^

comment on procedure aux_xml_get_value is 'Looking up and returns value of XML node with specified name (in `node_name`) from `xml_source`';

comment on parameter aux_xml_get_value.xml_source is 'Source XML to parse';
comment on parameter aux_xml_get_value.node_name is 'Name of XML node being searched for';
comment on parameter aux_xml_get_value.vtype is 'Type of value of XML node being searched for (default `str`). Allowed types: `str`, `int` (`long`), `float` (`double), `bool`, `date`, `time`, `datetime`, `node`';
comment on parameter aux_xml_get_value.req is 'Requiring status of XML node being searched for.
Allowed statuses:
- 0 (default) - not required;
- 1 - required (if node is not found procedure will return non zero `error_code` and non empty `error_text`);
- 2 (or more) - required (if node is not found procedure will raise exeption);';
comment on parameter aux_xml_get_value.node_index is 'The ordinal number of XML node being searched for (default is `1`). If `null`, all XML nodes with specified name will be returned.';
comment on parameter aux_xml_get_value.check_nil_attribute is 'Determines whether the XMLSchema-instance `nil` attribute should be checked.
Allowed values:
- null/0 or less - ignore `nil` attribute;
- 1 or more (default) - return `null` value of XML node if its has nil attribute wuth "true";';

comment on parameter aux_xml_get_value.val is 'Text representation of found XML node value';
comment on parameter aux_xml_get_value.val_int is 'Integer representation of found XML node value';
comment on parameter aux_xml_get_value.val_float is 'Real number representation of found XML node value';
comment on parameter aux_xml_get_value.val_double is 'Real number (with double precision) representation of found XML node value';
comment on parameter aux_xml_get_value.val_date is 'Date representation of found XML node value';
comment on parameter aux_xml_get_value.val_time is 'Time representation of found XML node value';
comment on parameter aux_xml_get_value.val_datetime is 'Date and time representation of XML node value';
comment on parameter aux_xml_get_value.time_zone is 'Timezone from value of found XML node with one of th follow types: `date`, `time`, `datetime`';
comment on parameter aux_xml_get_value.attributes is 'Attributes of found XML node';
comment on parameter aux_xml_get_value.node_number is 'The ordinal number of found XML node';
comment on parameter aux_xml_get_value.node_start is 'Start position of found XML node (position of first `<`)';
comment on parameter aux_xml_get_value.node_end is 'End position of found XML node (position of last `>`)';
comment on parameter aux_xml_get_value.value_start is 'Start position of value in found XML node (position of first symbol of value)';
comment on parameter aux_xml_get_value.value_end is 'End position of value in found XML node (position of last symbol of value)';
comment on parameter aux_xml_get_value.error_code is 'Error code (zero';
comment on parameter aux_xml_get_value.error_text is 'Описание ошибки. Если ошибок нет, то пустая строка';