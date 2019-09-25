set term ^ ;

-- Checks that `text` containing standalone `word` (not as a part of other word)
create or alter procedure mds_aux_text_contains_word(
    text_in blob sub_type text
    , word varchar(255)
    , case_sensitive smallint = 1
)
returns (
    text blob sub_type text
    , does_contain smallint
)
as
-- constants
-- -- NO WORD PART
declare WORD_SYMBOLS varchar(64) = '[:ALPHA:][:DIGIT:]А-ЯЁа-яё';
-- -- patterns (init later in code)
declare BEGIN_WITH_WORD_PATTERN varchar(255);
declare END_WITH_WORD_PATTERN varchar(255);
declare WORD_IN_THE_MIDDLE_PATTERN varchar(255);
begin
    text = text_in;
    does_contain = 0;

    BEGIN_WITH_WORD_PATTERN = word || '[^' || WORD_SYMBOLS || ']%';
    END_WITH_WORD_PATTERN = '%[^' || WORD_SYMBOLS || ']' || word;
    WORD_IN_THE_MIDDLE_PATTERN = '%[^' || WORD_SYMBOLS || ']' || word || '[^' || WORD_SYMBOLS || ']%';

    if (coalesce(case_sensitive, 1) = 0) then
    begin
        BEGIN_WITH_WORD_PATTERN = lower(BEGIN_WITH_WORD_PATTERN);
        END_WITH_WORD_PATTERN = lower(END_WITH_WORD_PATTERN);
        WORD_IN_THE_MIDDLE_PATTERN = lower(WORD_IN_THE_MIDDLE_PATTERN);

        word = lower(word);
        text = lower(text);
    end

    if (text similar to BEGIN_WITH_WORD_PATTERN
        or text similar to END_WITH_WORD_PATTERN
        or text similar to WORD_IN_THE_MIDDLE_PATTERN
        or text = word
    ) then does_contain = 1;

    suspend;
end^

set term ; ^

comment on procedure mds_aux_text_contains_word is 'Checks that `text` containing standalone `word` (not as a part of other word)';
comment on parameter mds_aux_text_contains_word.text_in is 'Text for checking';
comment on parameter mds_aux_text_contains_word.word is 'Searching word';
comment on parameter mds_aux_text_contains_word.case_sensitive is 'If not null or not zero, case of word in `text` must match case searching `word`';
comment on parameter mds_aux_text_contains_word.does_contain is '1 if `text` containins `word`, otherwise `0`';