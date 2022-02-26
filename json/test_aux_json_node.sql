SET LIST on;

set term ^ ;

execute block
returns (
    test_name varchar(255)
    , test_result varchar(16)
    , expected_value varchar(4096)
    , resulting_value varchar(4096)
    , summary varchar(32)
)
as
declare val blob sub_type text;
declare val_type varchar(16);
declare is_ok smallint;
declare total_count bigint;
declare success_count bigint;
declare val_req smallint;
-- constants
-- -- aux_json_node.human_readable input parameter
declare NO_FORMATTING smallint = 0;
declare HUMAN_READABLE_FORMATTING smallint = 1;
-- -- aux_json_node.required input parameter
declare OPTIONAL bigint = 0; -- 0 - no node (empty string) for null values;
declare REQUIRED_AS_NULL bigint = 1; -- 1 - empty node with `null` as value;
declare REQUIRED_AS_EMPTY bigint = 2; -- 2 - empty node with empty value (for `obj` - `{}`, for `list` - `[]`, for `str` - `""`);
-- -- aux_json_node.add_delimiter input parameter
declare NO_DELIMITER smallint = 0; -- 0 - without comma after json node
declare WITH_DELIMITER smallint = 1; -- 0 - witht comma after json node
begin
    total_count = 0;
    success_count = 0;

    -- -- -- --
    -- -- -- --
    for select 'num: simple' as n, 1 as val, '"number": 1' as expected_value from rdb$database union all
        select 'num: decimal' as n, 4.3 as val, '"number": 4.3' as expected_value from rdb$database union all
        select 'num: negative' as n, -3.90 as val, '"number": -3.90' as expected_value from rdb$database union all
        select 'num: eXponent' as n, '0.5e-89' as val, '"number": 0.5e-89' as expected_value from rdb$database union all
        select 'num: Exponent as string' as n, '4.6E+17' as val, '"number": 4.6E+17' as expected_value from rdb$database union all
        select 'num: extra zero at the begining' as n, '01.2' as val, '"number": null' as expected_value from rdb$database union all
        select 'num: not a number' as n, 'z0.2' as val, '"number": null' as expected_value from rdb$database
        into test_name, val, expected_value
    do
    begin
        resulting_value = (select node from aux_json_node('number', :val, 'num', :REQUIRED_AS_NULL, :NO_DELIMITER, :HUMAN_READABLE_FORMATTING));
        is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
        total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
        suspend;
    end
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    for select 'bool: 1 as true' as n, 1 as val, '"boolean": true' as expected_value from rdb$database union all
        select 'bool: 12 as true' as n, 12 as val, '"boolean": true' as expected_value from rdb$database union all
        select 'bool: -1 as true' as n, -1 as val, '"boolean": true' as expected_value from rdb$database union all
        select 'bool: True as true' as n, 'True' as val, '"boolean": true' as expected_value from rdb$database union all
        select 'bool: 0 as false' as n, 0 as val, '"boolean": false' as expected_value from rdb$database union all
        select 'bool: FaLsE as false' as n, 'FaLsE' as val, '"boolean": false' as expected_value from rdb$database
        into test_name, val, expected_value
    do
    begin
        resulting_value = (select node from aux_json_node('boolean', :val, 'bool', :REQUIRED_AS_NULL, :NO_DELIMITER, :HUMAN_READABLE_FORMATTING));
        is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
        total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
        suspend;
    end
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    for select 'list: with brackets' as n, '[1, 2, 3, 4]' as val, '"list":[1, 2, 3, 4]' as expected_value from rdb$database union all
        select 'list: with no brackets' as n, '1, 2, 3, 4' as val, '"list":[1, 2, 3, 4]' as expected_value from rdb$database union all
        select 'list: with braces ' as n, '{"a": 1}' as val, '"list":[{"a": 1}]' as expected_value from rdb$database
        into test_name, val, expected_value
    do
    begin
        resulting_value = (select node from aux_json_node('list', :val, 'list', :REQUIRED_AS_NULL, :NO_DELIMITER, :NO_FORMATTING));
        is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
        total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
        suspend;
    end
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    for select 'obj: with braces' as n, '{"x": "z", "y": 0}' as val, '"object":{"x": "z", "y": 0}' as expected_value from rdb$database union all
        select 'obj: with no braces' as n, '"x": "z", "y": 0' as val, '"object":{"x": "z", "y": 0}' as expected_value from rdb$database
        into test_name, val, expected_value
    do
    begin
        resulting_value = (select node from aux_json_node('object', :val, 'obj', :REQUIRED_AS_NULL, :NO_DELIMITER, :NO_FORMATTING));
        is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
        total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
        suspend;
    end
    -- -- -- --
    -- -- -- --


    -- -- -- --
    -- -- -- --
    for select 'datetime: format 0 (`YYYY-MM-DDThh:mm:ss' as n, 'datetime:0' as t, cast('01.02.2023 12:34:45' as timestamp) as val, '"dt": "2023-02-01T12:34:45"' as expected_value from rdb$database union all
        select 'datetime: format 1 (`YYYY-MM-DD hh:mm:ss`)' as n, 'datetime:1' as t, cast('01.02.2023 12:34:45' as timestamp) as val, '"dt": "2023-02-01 12:34:45"' as expected_value from rdb$database union all
        select 'datetime: timestamp as date' as n, 'date' as t, cast('01.02.2023 12:34:45' as timestamp) as val, '"dt": "2023-02-01"' as expected_value from rdb$database union all
        select 'date: date as date' as n, 'date' as t, cast('01.02.2023' as date) as val, '"dt": "2023-02-01"' as expected_value from rdb$database union all
        select 'time: timestamp as time' as n, 'time' as t, cast('01.02.2023 12:34:45' as timestamp) as val, '"dt": "12:34:45"' as expected_value from rdb$database union all
        select 'time: time as time' as n, 'time' as t, cast('12:34:45' as time) as val, '"dt": "12:34:45"' as expected_value from rdb$database
        into test_name, val_type, val, expected_value
    do
    begin
        resulting_value = (select node from aux_json_node('dt', :val, :val_type, :REQUIRED_AS_NULL, :NO_DELIMITER, :HUMAN_READABLE_FORMATTING));
        is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
        total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
        suspend;
    end
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    for select 'null: list as nothing' as n, :OPTIONAL as r, 'list' as t, '' as expected_value from rdb$database union all
        select 'null: list as null' as n, :REQUIRED_AS_NULL as r, 'list' as t, '"null": null' as expected_value from rdb$database union all
        select 'null: list as empty' as n, :REQUIRED_AS_EMPTY as r, 'list' as t, '"null": []' as expected_value from rdb$database union all
        select 'null: obj as nothing' as n, :OPTIONAL as r, 'obj' as t, '' as expected_value from rdb$database union all
        select 'null: obj as null' as n, :REQUIRED_AS_NULL as r, 'obj' as t, '"null": null' as expected_value from rdb$database union all
        select 'null: obj as empty' as n, :REQUIRED_AS_EMPTY as r,'obj' as t, '"null": {}' as expected_value from rdb$database union all
        select 'null: str as nothing' as n, :OPTIONAL as r, 'str' as t, '' as expected_value from rdb$database union all
        select 'null: str as null' as n, :REQUIRED_AS_NULL as r, 'str' as t, '"null": null' as expected_value from rdb$database union all
        select 'null: str as empty' as n, :REQUIRED_AS_EMPTY as r, 'str' as t, '"null": ""' as expected_value from rdb$database
        into test_name, val_req, val_type, expected_value
    do
    begin
        val = null;
        resulting_value = (select node from aux_json_node('null', :val, :val_type, :val_req, :NO_DELIMITER, :HUMAN_READABLE_FORMATTING));
        is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
        total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
        suspend;
    end
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_name = 'root unnamed node';
    expected_value = '{"a":"b","c":"d"}';
    resulting_value = (select node from aux_json_node(null
                                                        , (select node from aux_json_node('a', 'b', 'str', :OPTIONAL, :WITH_DELIMITER, :NO_FORMATTING))
                                                        ||(select node from aux_json_node('c', 'd', 'str'))
                                                        , 'obj', :REQUIRED_AS_NULL));
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --


    test_name = 'ALL TESTS SUMMARY';
    expected_value = total_count;
    resulting_value = success_count;
    test_result = iif(success_count = total_count, 'PASSED', 'FAILED');
    summary = iif(success_count = total_count, 'ALL TESTS PASSED', (total_count - success_count) ||  ' of ' || total_count || ' TESTS FAILED');
    suspend;
end^

set term ; ^
