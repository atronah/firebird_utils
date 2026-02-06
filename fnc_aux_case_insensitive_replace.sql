set term ^ ;

create or alter function aux_case_insensitive_replace(
    source_text varchar(16384)
    , replacement_part varchar(16384)
    , new_part varchar(16384) = null
)
returns varchar(16384)
as
declare prev_source_text varchar(16384);
declare pos bigint;
declare new_part_len bigint;
begin
    new_part = coalesce(new_part, '');
    new_part_len = char_length(new_part);

    while (source_text containing replacement_part) do
    begin
        prev_source_text = source_text;
        pos = position(upper(replacement_part) in upper(prev_source_text));

        source_text = substring(prev_source_text from 1 for pos - 1)
                        || new_part
                        || substring(prev_source_text from pos + new_part_len);

        -- to prevent infinity loop compare text before and after replace
        if (source_text is not distinct from prev_source_text)
            then exit;
    end

    return source_text;
end^

set term ; ^

comment on function aux_case_insensitive_replace is 'Replaces all occurrences of a substring in a string with case insensitive.';