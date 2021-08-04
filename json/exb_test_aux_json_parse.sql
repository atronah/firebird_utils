SET LIST on;

set term ^ ;

execute block
returns (
    test_name varchar(255)
    , test_result smallint
    , expected_value varchar(4096)
    , resulting_value varchar(4096)
    , summary varchar(32)
)
as
declare test_json blob sub_type text;
declare total_count bigint;
declare success_count bigint;
begin
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
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_json = '"text_param": "text value"';
    test_name = 'number of all found json pairs "param:value" in json with only one object without trailing "{" and "}"';
    resulting_value = (select count(*) from aux_json_parse(:test_json));
    expected_value = 1; -- expected number 1 because source json contains only one parameter
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'start/end positions of found node, its path, type, index, name and value';
    -- node_start|node_end|node_path|node_index|value_type|name|val|error_code
    expected_value = '1|26|/|0|string|text_param|text value|0';
    resulting_value = (select first 1
                             node_start || '|' || node_end || '|' || node_path || '|' || node_index || '|' || value_type || '|' || name || '|' || val || '|' || error_code
                            from aux_json_parse(:test_json));
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
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
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
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
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
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
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'complex: count';
    resulting_value = (select count(*) from aux_json_parse(:test_json));
    expected_value = 16;
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
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
                || '|' || (select count(*) from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/-/d.1/' and value_type = 'object' and val like '"%":%' );
    expected_value = '0:-1:number|0:0:number|0:1.0:number|/-/a/b/c/d/-/d.1/-/|3';
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'nested obj/arr: d.2.* zero indexes, values and types';
    resulting_value = (select node_index || ':' || val || ':' || value_type from aux_json_parse(:test_json) where name = 'd.2.1')
                || '|' || (select node_index || ':' || val || ':' || value_type  from aux_json_parse(:test_json) where name = 'd.2.2')
                || '|' || (select node_index || ':' || val || ':' || value_type  from aux_json_parse(:test_json) where name = 'd.2.3')
                || '|' || (select distinct node_path from aux_json_parse(:test_json) where name starts with 'd.2.')
                || '|' || (select count(*) from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/-/d.2/' and value_type = 'object' and val like '"%":%');
    expected_value = '0:-1.1:number|0:0.3:number|0:1.5:number|/-/a/b/c/d/-/d.2/-/|3';
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'nested obj/arr: d array';
    expected_value = '0:array|1|1|0';
    resulting_value = (select node_index || ':' || value_type from aux_json_parse(:test_json) where node_path = '/-/a/b/c/' and name = 'd')
                    || '|' || (select count(*) from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/' and node_index = 0)
                    || '|' || (select count(*) from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/' and node_index = 1)
                    || '|' || (select count(*) from aux_json_parse(:test_json) where node_path = '/-/a/b/c/d/' and node_index = 2);
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
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
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'nested obj/arr: count';
    -- 1 root `object`
    -- 1 `object` "a" + 1 `object` "b" + 1 `object` "c"
    -- 1 `array` "d" + 2 `object` inside `array` "d"
    -- 1 `array` "d.1" + 3 `object` inside `array` "d.1" + 3 `string:num` of each item in `array` "d.1"
    -- 1 `array` "d.2" + 3 `object` inside `array` "d.2" + 3 `string:num` of each item in `array` "d.2"
    resulting_value = (select count(*) from aux_json_parse(:test_json));
    expected_value = 21;
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
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
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
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
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --
end^

set term ; ^