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
    test_name = 'just text';
    -- start_pos|end_pos|node_path|node_index|node_type|node_name|node_content|error_code
    expected_value = '6|16|/|0|string|null|just text|0';
    resulting_value = (select first 1
                             start_pos || '|' || end_pos || '|' || node_path || '|' || node_index || '|' || node_type || '|' || coalesce(node_name, 'null') || '|' || node_content || '|' || error_code
                            from aux_json_parse(:test_json));
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_json = '"text_param": "text value"';
    test_name = 'param: count';
    expected_value = 1;
    resulting_value = (select count(*) from aux_json_parse(:test_json));
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'param: values';
    -- start_pos|end_pos|node_path|node_index|node_type|node_name|node_content|error_code
    expected_value = '1|26|/|0|string|text_param|text value|0';
    resulting_value = (select first 1
                             start_pos || '|' || end_pos || '|' || node_path || '|' || node_index || '|' || node_type || '|' || node_name || '|' || node_content || '|' || error_code
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
                        "my array": [
                            "array item 1",
                            "array item 2",
                            "array item 3",
                        ],
                        "some object": {
                            "object.text": "child text value",
                            "object.num": -932.45    ,
                            "object.obj": {
                                "mixed array": [
                                    "just string",
                                    140,
                                    { "object as array item" : "simple" },
                                    "number as array item": 0.98
                                ],
                            },
                        },
                    }';
    test_name = 'complex: some param';
    -- left(4)|right(4)|node_path|node_index|node_type|node_name|node_content|error_code
    expected_value = '"som|lue"|/-/|0|string|some param|text value|0';
    resulting_value = (select first 1
                            substring(:test_json from start_pos for 4)
                                || '|' || substring(:test_json from end_pos - 4 + 1 for 4)
                                || '|' || node_path || '|' || node_index || '|' || node_type
                                || '|' || node_name || '|' || node_content || '|' || error_code
                            from aux_json_parse(:test_json));
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'complex: my array';
    -- node_type|left(node_content, 4)|right(node_content,4)|error_code
    expected_value = '"my |   ]|/-/|1|array|"arr| 3",|0';
    resulting_value = (select first 1
                            substring(:test_json from start_pos for 4)
                                || '|' || substring(:test_json from end_pos - 4 + 1 for 4)
                                || '|' || node_path || '|' || node_index
                                || '|' || node_type
                                || '|' || left(node_content, 4)
                                || '|' || right(node_content, 4)
                                || '|' || error_code
                            from aux_json_parse(:test_json)
                        where node_name = 'my array');
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'complex: object as array item';
    -- left(4)|right(4)|node_path|node_index|node_type|left(node_content, 4)|right(node_content,4)|error_code
    expected_value = 'object|"obj|ple"|0';
    resulting_value = (select first 1
                                node_type
                                || '|' || left(node_content, 4)
                                || '|' || right(node_content, 4)
                                || '|' || error_code
                            from aux_json_parse(:test_json)
                        where node_path = '/-/some object/object.obj/mixed array/' and node_index = 2);

    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'complex: count';
    expected_value = 16;
    resulting_value = (select count(*) from aux_json_parse(:test_json));
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --
end^

set term ; ^