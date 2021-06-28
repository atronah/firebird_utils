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
    test_json = '{
        "items": [
            {"type" : "title", "value": "Title"},
            {"type" : "content", "value": {"param1": 1, "param": 2}},
            {"type" : "comment", "value": "Comment"}
        ]
    }';
    test_name = 'objects with different type of content: get title';
    expected_value = '{"ty|le"}|Title|string|/-/items/|0';
    resulting_value = (select first 1
                                left(node, 4) || '|' || right(node, 4) || '|' || val || '|' || value_type
                                || '|' || node_path || '|' || node_index
                            from aux_json_get_node(:test_json, 'type', 'title', 'value'));
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'objects with different type of content: get comment';
    expected_value = '{"ty|nt"}|Comment|string|/-/items/|2';
    resulting_value = (select first 1
                                left(node, 4) || '|' || right(node, 4) || '|' || val || '|' || value_type
                                || '|' || node_path || '|' || node_index
                            from aux_json_get_node(:test_json, 'type', 'comment', 'value'));
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'objects with different type of content: get content';
    expected_value = '{"ty| 2}}|"param1": 1, "param": 2|object|/-/items/|1';
    resulting_value = (select first 1
                                left(node, 4) || '|' || right(node, 4) || '|' || val|| '|' || value_type
                                || '|' || node_path || '|' || node_index
                            from aux_json_get_node(:test_json, 'type', 'content', 'value'));
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_json = '{
        "items": {
            "itemA": {"type" : "A", "value": "A value"},
            "itemB": {"type" : "B", "value": "B value"},
            "itemC": {"type" : "C", "value": "C value"},
        }
    }';
    test_name = 'node name';
    expected_value = 'itemA:A value|itemB:B value|itemC:C value';
    resulting_value = coalesce((select node_name || ':' || val from aux_json_get_node(:test_json, 'type', 'A', 'value')), 'null')
            || '|' || coalesce((select node_name || ':' || val from aux_json_get_node(:test_json, 'type', 'B', 'value')), 'null')
            || '|' || coalesce((select node_name || ':' || val from aux_json_get_node(:test_json, 'type', 'C', 'value')), 'null');
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_json = '{
        "items": [
            {"type" : "A", "value": "A value"},
            {"type" : "B", "value": "B1 value"},
            {"type" : "B", "value": "B2 value"},
            {"type" : "C", "value": "C value"},
        ]
    }';
    test_name = 'few nodes with the same type';
    expected_value = '2|B1 value|B2 value';
    resulting_value = (select count(*) from aux_json_get_node(:test_json, 'type', 'B'))
                || '|' || coalesce((select val from aux_json_get_node(:test_json, 'type', 'B', 'value') where node_index = 1), 'null')
                || '|' || coalesce((select val from aux_json_get_node(:test_json, 'type', 'B', 'value') where node_index = 2), 'null');
    test_result = iif(resulting_value is not distinct from expected_value, 1, 0);
    total_count = total_count + 1; success_count = success_count + test_result; summary = success_count || '/' || total_count;
    suspend;

    -- -- -- --
    -- -- -- --
end^

set term ; ^