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
declare source_text varchar(4096);
declare symbols_list varchar(4096);
declare strip_rule smallint;
declare substitute varchar(16);
-- Constants
-- -- numbers
declare NUMBERS varchar(10) = '0123456789';
-- -- Stripping rule (`strip_rule`)
declare REMOVE_GIVEN_SYMBOLS smallint = 0; -- 0 - removes from source text (`source_text`)  all symbols specified in `symbols_list`
declare REMOVE_ALL_EXCEPT_GIVEN_SYMBOLS smallint = 1; -- 1 - removes from source text (`source_text`) all symbols EXCEPT specified in `symbols_list`
declare REMOVE_REPEAT_OF_GIVEN_SYMBOLS smallint = 2; -- 2 - removes from source text (`source_text`) the second and subsequent repetitions of symbol from `symbols_list`
begin
    total_count = 0;
    success_count = 0;

    stmt = 'select affected_symbols || '':'' || result from aux_strip_text(:source_text, :symbols_list, :strip_rule, :substitute)';

    -- -- -- --
    -- -- -- --
    test_name = 'empty string';
    source_text = ''; symbols_list = NUMBERS; strip_rule = :REMOVE_GIVEN_SYMBOLS; substitute = null;
    source_data = '''' || source_text || ''', ''' || symbols_list || ''', ' || strip_rule || ', ''' || coalesce(substitute, 'null') || '''';
    expected_value = '0:';
    resulting_value = null;
    execute statement (stmt) (source_text := :source_text, symbols_list := :symbols_list, strip_rule := :strip_rule, substitute := :substitute) into resulting_value;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'OK', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --
    test_name = 'removes numbers from text';
    source_text = '123abc45-67qwe890rty'; symbols_list = NUMBERS; strip_rule = :REMOVE_GIVEN_SYMBOLS; substitute = null;
    source_data = '''' || source_text || ''', ''' || symbols_list || ''', ' || strip_rule || ', ''' || coalesce(substitute, 'null') || '''';
    expected_value = '10:abc-qwerty';
    resulting_value = null;
    execute statement (stmt) (source_text := :source_text, symbols_list := :symbols_list, strip_rule := :strip_rule, substitute := :substitute) into resulting_value;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'OK', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --
    test_name = 'remove everything except numbers from text';
    source_text = '123abc45-67qwe890rty'; symbols_list = NUMBERS; strip_rule = :REMOVE_ALL_EXCEPT_GIVEN_SYMBOLS; substitute = null;
    source_data = '''' || source_text || ''', ''' || symbols_list || ''', ' || strip_rule || ', ''' || coalesce(substitute, 'null') || '''';
    expected_value = '10:1234567890';
    resulting_value = null;
    execute statement (stmt) (source_text := :source_text, symbols_list := :symbols_list, strip_rule := :strip_rule, substitute := :substitute) into resulting_value;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'OK', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --
    test_name = 'replace all spaces by underline';
    source_text = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt';
    symbols_list = ' '; strip_rule = :REMOVE_GIVEN_SYMBOLS; substitute = '_';
    source_data = '''' || source_text || ''', ''' || symbols_list || ''', ' || strip_rule || ', ''' || coalesce(substitute, 'null') || '''';
    expected_value = '12:Lorem_ipsum_dolor_sit_amet,_consectetur_adipiscing_elit,_sed_do_eiusmod_tempor_incididunt';
    resulting_value = null;
    execute statement (stmt) (source_text := :source_text, symbols_list := :symbols_list, strip_rule := :strip_rule, substitute := :substitute) into resulting_value;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'OK', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --
    test_name = 'removes repating lower vowels';
    source_text = 'Heeellooo woooorld, I am yoooour frieeeend, BROOO';
    symbols_list = 'aeiouy'; strip_rule = :REMOVE_REPEAT_OF_GIVEN_SYMBOLS; substitute = null;
    source_data = '''' || source_text || ''', ''' || symbols_list || ''', ' || strip_rule || ', ''' || coalesce(substitute, 'null') || '''';
    expected_value = '13:Hello world, I am your friend, BROOO';
    resulting_value = null;
    execute statement (stmt) (source_text := :source_text, symbols_list := :symbols_list, strip_rule := :strip_rule, substitute := :substitute) into resulting_value;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'OK', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --
    test_name = 'replaces all repating lower vowels by a question mark';
    source_text = 'Heeellooo woooorld, I am yoooour frieeeend, BROOO';
    symbols_list = 'aeiouy'; strip_rule = :REMOVE_REPEAT_OF_GIVEN_SYMBOLS; substitute = '?';
    source_data = '''' || source_text || ''', ''' || symbols_list || ''', ' || strip_rule || ', ''' || coalesce(substitute, 'null') || '''';
    expected_value = '13:He??llo?? wo???rld, I am yo???ur frie???nd, BROOO';
    resulting_value = null;
    execute statement (stmt) (source_text := :source_text, symbols_list := :symbols_list, strip_rule := :strip_rule, substitute := :substitute) into resulting_value;
    is_ok = iif(resulting_value is not distinct from expected_value, 1, 0); test_result = decode(is_ok, 1, 'OK', 'FAILED');
    total_count = total_count + 1; success_count = success_count + is_ok; summary = success_count || '/' || total_count;
    suspend;
    -- -- -- --
    -- -- -- --
    test_name = 'nothing to do';
    source_text = 'Alphabetical text'; symbols_list = NUMBERS; strip_rule = :REMOVE_GIVEN_SYMBOLS; substitute = '?';
    source_data = '''' || source_text || ''', ''' || symbols_list || ''', ' || strip_rule || ', ''' || coalesce(substitute, 'null') || '''';
    expected_value = '0:Alphabetical text';
    resulting_value = null;
    execute statement (stmt) (source_text := :source_text, symbols_list := :symbols_list, strip_rule := :strip_rule, substitute := :substitute) into resulting_value;
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