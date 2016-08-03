set term ^ ;

create or alter procedure aux_split_text(
    text blob sub_type text
    , delimiter varchar(32) = ','
    , trim_part smallint = 1
)
returns(
    row smallint
    , part blob sub_type text
)
as
declare i smallint;
declare text_len integer;
declare delimiter_len integer;
begin
    if (coalesce(text, '') = '') then exit;

    i = 0;
    row = 0;
    text_len = char_length(text);
    delimiter_len = char_length(delimiter);

    while (i <= text_len + 1) do
    begin
        i = i + 1;
        if ((substring(text from i for delimiter_len) = delimiter) or (i = text_len)) then
        begin
            if (i = text_len) then i = i + 1;

            part = cast(substring(text from 1 for i - 1) as varchar(16384));
            part = iif(trim_part = 1, trim(part), part);
            text = substring(text from i + delimiter_len);

            row = row + 1;
            suspend;
            i = 0;
        end
    end
end^

set term ; ^