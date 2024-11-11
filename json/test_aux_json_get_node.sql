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
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'objects with different type of content: get comment';
    expected_value = '{"ty|nt"}|Comment|string|/-/items/|2';
    resulting_value = (select first 1
                                left(node, 4) || '|' || right(node, 4) || '|' || val || '|' || value_type
                                || '|' || node_path || '|' || node_index
                            from aux_json_get_node(:test_json, 'type', 'comment', 'value'));
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;

    test_name = 'objects with different type of content: get content';
    expected_value = '{"ty| 2}}|{"param1": 1, "param": 2}|object|/-/items/|1';
    resulting_value = (select first 1
                                left(node, 4) || '|' || right(node, 4) || '|' || val|| '|' || value_type
                                || '|' || node_path || '|' || node_index
                            from aux_json_get_node(:test_json, 'type', 'content', 'value'));
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
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
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
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
    -- getting only objects with `type = "B"`
    -- count items|first item|second item
    expected_value = '2|B1 value|B2 value';
    resulting_value = (select count(*) from aux_json_get_node(:test_json, 'type', 'B'))
                || '|' || coalesce((select val from aux_json_get_node(:test_json, 'type', 'B', 'value') where node_index = 1), 'null')
                || '|' || coalesce((select val from aux_json_get_node(:test_json, 'type', 'B', 'value') where node_index = 2), 'null');
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'PASSED', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --
    
    -- -- -- --
    -- -- -- --
    test_json = '{
                        "system": "urn:oid:1.2.643.2.69.1.1.1.6.14",
                        "value": "7828:213421",
                        "period": {"start": "2015-05-05"},
                        "assigner": {
                            "identifier": {
                                "system": "urn:oid:1.2.643.5.1.13.13.99.2.206",
                                "value": "78"
                            },
                            "display": "УФМС РФ № 56 Фрунзенского района:345-001"
                        }
                    }';
    test_name = 'nested objects';
    -- getting only objects with `type = "B"`
    -- count items|first item|second item
    expected_value = '1|7828:213421';
    resulting_value = (select count(*) from aux_json_get_node(:test_json, 'system', 'urn:oid:1.2.643.2.69.1.1.1.6.14', 'value'))
                || '|' || coalesce((select max(val) from aux_json_get_node(:test_json, 'system', 'urn:oid:1.2.643.2.69.1.1.1.6.14', 'value') ), 'null');

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