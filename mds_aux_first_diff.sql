set term ^ ;

-- Crops input strings `string1` and `string2` to the left of start position of difference
-- for example for input
--     string1 = 'foobar'
--     string2 = 'foozom'
--     context_size = 1
-- procedure returns:
--     trimmed_string1 = 'obar'
--     trimmed_string2 = 'ozom'
-- where first 'o' is context, and 2-4 symols is difference
create or alter procedure mds_aux_first_diff(
    string1 blob sub_type text -- The first string to compare
    , string2 blob sub_type text -- The second string to compare
    , context_size smallint = 32 -- How many characters should be displayed before difference
)
returns(
    trimmed_string1 blob sub_type text -- cropped first string
    , trimmed_string2 blob sub_type text -- cropped first string
    , diff_position bigint -- position of difference starting
)
as
declare text_len bigint;
declare pos bigint;
begin
    text_len = minvalue(char_length(string1), char_length(string2));
    pos = 1;
    while (pos <= text_len) do
    begin
        if (substring(string1 from pos for 1) <> substring(string2 from pos for 1)) then break;
        pos = pos + 1;
    end
    if (pos > text_len) then pos = 0;
    diff_position = pos;
    trimmed_string1 = substring(string1 from maxvalue(1, pos - context_size));
    trimmed_string2 = substring(string2 from maxvalue(1, pos - context_size));
    suspend;
end^

set term ; ^