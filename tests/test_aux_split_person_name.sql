SET LIST on;

set term ^ ;

execute block
returns (
    test_name varchar(255)
    , source_data varchar(1024)
    , expected_value varchar(1024)
    , resulting_value varchar(1024)
    , test_result varchar(16)
    , summary varchar(32)
)
as
declare is_ok smallint;
declare stmt varchar(255);
declare total_count bigint;
declare success_count bigint;
-- input params of procedure `aux_strip_text`
declare source_text varchar(256);
declare use_case_to_split smallint;
begin
    total_count = 0;
    success_count = 0;

    stmt = 'select coalesce(lastname, ''null'') || '' '' || coalesce(firstname, ''null'') || '' '' || coalesce(midname, ''null'')
            from aux_split_person_name(:source_text, :use_case_to_split)';

    -- -- -- --
    -- -- -- --
    test_name = 'empty string';
    source_text = ''; use_case_to_split = 0;
    source_data = '''' || source_text || ''', ' || use_case_to_split;
    expected_value = 'null null null';
    resulting_value = null;
    execute statement (stmt) (source_text := :source_text, use_case_to_split := :use_case_to_split) into resulting_value;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'OK', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_name = 'simple name';
    source_text = 'Lastname Firstname Midname'; use_case_to_split = 0;
    source_data = '''' || source_text || ''', ' || use_case_to_split;
    expected_value = 'Lastname Firstname Midname';
    resulting_value = null;
    execute statement (stmt) (source_text := :source_text, use_case_to_split := :use_case_to_split) into resulting_value;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'OK', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_name = 'simple name without spaces';
    source_text = 'LastnameFirstnameMidname'; use_case_to_split = 1;
    source_data = '''' || source_text || ''', ' || use_case_to_split;
    expected_value = 'Lastname Firstname Midname';
    resulting_value = null;
    execute statement (stmt) (source_text := :source_text, use_case_to_split := :use_case_to_split) into resulting_value;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'OK', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_name = 'Name with initials without spaces';
    source_text = 'LastnameFM'; use_case_to_split = 1;
    source_data = '''' || source_text || ''', ' || use_case_to_split;
    expected_value = 'Lastname F M';
    resulting_value = null;
    execute statement (stmt) (source_text := :source_text, use_case_to_split := :use_case_to_split) into resulting_value;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'OK', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_name = 'Name with initials, spaces and dots';
    source_text = 'Lastname F. M.'; use_case_to_split = 1;
    source_data = '''' || source_text || ''', ' || use_case_to_split;
    expected_value = 'Lastname F. M.';
    resulting_value = null;
    execute statement (stmt) (source_text := :source_text, use_case_to_split := :use_case_to_split) into resulting_value;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'OK', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_name = 'Double lastname with initials, spaces and dots';
    source_text = 'Last-Name F. M.'; use_case_to_split = 1;
    source_data = '''' || source_text || ''', ' || use_case_to_split;
    expected_value = 'Last-Name F. M.';
    resulting_value = null;
    execute statement (stmt) (source_text := :source_text, use_case_to_split := :use_case_to_split) into resulting_value;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'OK', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --

    -- -- -- --
    -- -- -- --
    test_name = 'Double lastname with initials, spaces and dots and with extra data';
    source_text = 'Last-Name F. M. (extra data)'; use_case_to_split = 1;
    source_data = '''' || source_text || ''', ' || use_case_to_split;
    expected_value = 'Last-Name F. M.';
    resulting_value = null;
    execute statement (stmt) (source_text := :source_text, use_case_to_split := :use_case_to_split) into resulting_value;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'OK', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --


    test_name = 'ALL TESTS SUMMARY';
    source_data = null;
    expected_value = total_count;
    resulting_value = success_count;
    test_result = iif(success_count = total_count, 'PASSED', 'FAILED');
    summary = iif(success_count = total_count, 'ALL TESTS PASSED', (total_count - success_count) ||  ' of ' || total_count || ' TESTS FAILED');
    suspend;
end^

set term ; ^