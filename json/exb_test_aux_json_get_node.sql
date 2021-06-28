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
end^

set term ; ^