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
declare is_ok smallint;
declare test_json blob sub_type text;
declare total_count bigint;
declare success_count bigint;
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    total_count = 0;
    success_count = 0;

    -- -- -- --
    -- -- -- --
    test_json = ASCII_CHAR(13) || ASCII_CHAR(10) || '   "just text" ';
    test_name = 'parse simple text as json';
    resulting_value = (select first 1
                             node_start
                            || '|' || node_end
                            || '|' || node_path
                            || '|' || node_index
                            || '|' || value_type
                            || '|' || coalesce(name, 'null')
                            || '|' || val
                            || '|' || error_code
                            from aux_json_parse(:test_json));
    expected_value = '6|16|/|0|string|null|just text|0';
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_json = '"text_param": "text value"';
    test_name = 'number of all found json pairs "param:value" in json with only one object without trailing "{" and "}"';
    resulting_value = (select count(*) from aux_json_parse(:test_json));
    expected_value = 1; -- expected number 1 because source json contains only one parameter
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'start/end positions of found node, its path, type, index, name and value';
    -- node_start|node_end|node_path|node_index|value_type|name|val|error_code
    expected_value = '1|26|/|0|string|text_param|text value|0';
    resulting_value = (select first 1
                             node_start || '|' || node_end || '|' || node_path || '|' || node_index || '|' || value_type || '|' || name || '|' || val || '|' || error_code
                            from aux_json_parse(:test_json));
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_json = '   {
                        "some param": "text value",
                        "my array": ["array item 1", "array item 2", "array item 3",],
                        "some object": {
                            "object.text": "child text value",
                            "object.num": -932.45    ,
                            "object.obj": {
                                "mixed array": ["just string",
                                                140,
                                                { "object as array item" : "simple" },
                                                "number as array item": 0.98],
                            },
                        },
                    }';
    test_name = 'complex: some param';
    resulting_value = (select first 1
                            substring(:test_json from node_start for 4)
                                || '|' || substring(:test_json from node_end - 4 + 1 for 4)
                                || '|' || node_path || '|' || node_index || '|' || value_type
                                || '|' || name || '|' || val || '|' || error_code
                            from aux_json_parse(:test_json));
    expected_value = '"som|lue"|/-/|0|string|some param|text value|0';
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'complex: my array';
    resulting_value = (select first 1
                            substring(:test_json from node_start for 4)
                                || '|' || substring(:test_json from node_end - 4 + 1 for 4)
                                || '|' || node_path
                                || '|' || node_index
                                || '|' || value_type
                                || '|' || left(val, 4)
                                || '|' || right(val, 4)
                                || '|' || substring(:test_json from value_start for 4)
                                || '|' || substring(:test_json from value_end - 4 + 1 for 4)
                                || '|' || error_code
                            from aux_json_parse(:test_json)
                        where name = 'my array');
    expected_value = '"my |3",]|/-/|1|array|["ar|3",]|["ar|3",]|0';
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;

    test_name = '3d item (with index = 2) in mixed array (this item has type "object")';
    resulting_value = (select first 1
                                value_type
                                || '|' || left(val, 4)
                                || '|' || right(val, 4)
                                || '|' || error_code
                            from aux_json_parse(:test_json)
                        where node_path = '/-/some object/object.obj/mixed array/' and node_index = 2);
    expected_value = 'object|{ "o|e" }|0';
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'complex: count';
    resulting_value = (select count(*) from aux_json_parse(:test_json));
    expected_value = 16;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --


    -- -- -- --
    -- -- -- --
    test_json = '{
        "a": {
            "b": {
                "c": {
                    "d": [
                        {"d.1": [{"d.1.1": -1}, {"d.1.2": 0}, {"d.1.3": 1.0}]},
                        {"d.2": [{"d.2.1": -1.1}, {"d.2.2": 0.3}, {"d.2.3": 1.5}]}
                    ]
                },
            },
        },
    }';
    test_name = 'nested obj/arr: d.1.* zero indexes, values and types, and common path';
    resulting_value = (select node_index || ':' || val || ':' || value_type from aux_json_parse(:test_json) where name = 'd.1.1')
                || '|' || (select node_index || ':' || val || ':' || value_type  from aux_json_parse(:test_json) where name = 'd.1.2')
                || '|' || (select node_index || ':' || val || ':' || value_type  from aux_json_parse(:test_json) where name = 'd.1.3')
                || '|' || (select distinct node_path from aux_json_parse(:test_json) where name starts with 'd.1.')
                || '|' || (select count(*) from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/-/d.1/' and value_type = 'object' and val similar to '${"[^"]+":[^}]+$}' escape '$');
    expected_value = '0:-1:number|0:0:number|0:1.0:number|/-/a/b/c/d/-/d.1/-/|3';
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'nested obj/arr: d.2.* zero indexes, values and types';
    resulting_value = (select node_index || ':' || val || ':' || value_type from aux_json_parse(:test_json) where name = 'd.2.1')
                || '|' || (select node_index || ':' || val || ':' || value_type  from aux_json_parse(:test_json) where name = 'd.2.2')
                || '|' || (select node_index || ':' || val || ':' || value_type  from aux_json_parse(:test_json) where name = 'd.2.3')
                || '|' || (select distinct node_path from aux_json_parse(:test_json) where name starts with 'd.2.')
                || '|' || (select count(*) from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/-/d.2/' and value_type = 'object' and val similar to '${"[^"]+":[^}]+$}' escape '$');
    expected_value = '0:-1.1:number|0:0.3:number|0:1.5:number|/-/a/b/c/d/-/d.2/-/|3';
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'nested obj/arr: d array';
    expected_value = '0:array|1|1|0';
    resulting_value = (select node_index || ':' || value_type from aux_json_parse(:test_json) where node_path = '/-/a/b/c/' and name = 'd')
                    || '|' || (select count(*) from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/' and node_index = 0)
                    || '|' || (select count(*) from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/' and node_index = 1)
                    || '|' || (select count(*) from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/' and node_index = 2);
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    test_name = 'nested obj/arr: levels';
    resulting_value = (select distinct level from aux_json_parse(:test_json) where node_path = '/') -- 0
                    || '|' || (select distinct level from aux_json_parse(:test_json) where node_path = '/-/') -- 1
                    || '|' || (select distinct level from aux_json_parse(:test_json) where node_path = '/-/a/') -- 2
                    || '|' || (select distinct level from aux_json_parse(:test_json) where node_path = '/-/a/b/') -- 3
                    || '|' || (select distinct level from aux_json_parse(:test_json) where node_path = '/-/a/b/c/') -- 4
                    || '|' || (select distinct level from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/') -- 5
                    || '|' || (select distinct level from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/-/') -- 6
                    || '|' || (select distinct level from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/-/d.1/') -- 7
                    || '|' || (select distinct level from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/-/d.2/') -- 7
                    || '|' || (select distinct level from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/-/d.2/-/') -- 8
                    || '|' || (select distinct level from aux_json_parse(:test_json) where name starts with 'd.1.')
                    || '|' || (select distinct level from aux_json_parse(:test_json) where name starts with 'd.2.')
                    ;
    expected_value = '0|1|2|3|4|5|6|7|7|8|8|8';
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'nested obj/arr: count';
    -- 1 root `object`
    -- 1 `object` "a" + 1 `object` "b" + 1 `object` "c"
    -- 1 `array` "d" + 2 `object` inside `array` "d"
    -- 1 `array` "d.1" + 3 `object` inside `array` "d.1" + 3 `string:num` of each item in `array` "d.1"
    -- 1 `array` "d.2" + 3 `object` inside `array` "d.2" + 3 `string:num` of each item in `array` "d.2"
    resulting_value = (select count(*) from aux_json_parse(:test_json));
    expected_value = 21;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_json = '{
        "a": [1 2 3]
    }';
    test_name = 'commas between array items';
    resulting_value = (select count(*) from aux_json_parse(:test_json) where node_path = '/-/a/' and val = 1 and error_code = 7);
    expected_value = '1';
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_json = '{
        "a": {"z": "y" "f": "e"}
    }';
    test_name = 'commas between array items';
    resulting_value = (select count(*) from aux_json_parse(:test_json) where error_code = 7);
    expected_value = '1';
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_json = '"text_param": "text with escaped \"quotes\""';
    test_name = 'processing escaped quotes inside string value';
    resulting_value = (select value_type || ': ' || val from aux_json_parse(:test_json) where name = 'text_param');
    expected_value = 'string: text with escaped "quotes"'; -- expected number 1 because source json contains only one parameter
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_json = '"text_param": "some \"quoted with \\\"nested sub-quoted\\\" part\" text"';
    test_name = 'processing double escaped quotes inside string value';
    resulting_value = (select value_type || ': ' || val from aux_json_parse(:test_json) where name = 'text_param');
    expected_value = 'string: some "quoted with \"nested sub-quoted\" part" text'; -- expected number 1 because source json contains only one parameter
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_json = '"text_param": "text with escaped backslash just before end quote\\"';
    test_name = 'processing end quote after escaped backslash inside string value';
    resulting_value = (select value_type || ': ' || val from aux_json_parse(:test_json) where name = 'text_param');
    expected_value = trim('string: text with escaped backslash just before end quote\ '); -- expected number 1 because source json contains only one parameter
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_json = '"text_param": "text\twith control characters\r\nlike newline and tab"';
    test_name = 'test supporting control characters `\t`, `\r`, `\n`';
    resulting_value = (select value_type || ': ' || val from aux_json_parse(:test_json) where name = 'text_param');
    expected_value = trim('string: text' || ascii_char(9) || 'with control characters' || ascii_char(13) || ascii_char(10) || 'like newline and tab'); -- expected number 1 because source json contains only one parameter
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    test_name = 'ALL TESTS SUMMARY';
    test_json = null;
    expected_value = total_count;
    resulting_value = success_count;
    test_result = iif(success_count = total_count, 'PASSED', 'FAILED');
    summary = iif(success_count = total_count, 'ALL TESTS PASSED', (total_count - success_count) ||  ' of ' || total_count || ' TESTS FAILED');
    suspend;
end^

set term ; ^
