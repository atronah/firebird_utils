set term ^ ;

create or alter procedure aux_split_text(
    text varchar(32000)
    , delimiter varchar(32) = ','
    , trim_part smallint = 1
)
returns(
    idx smallint
    , part varchar(32000)
)
as
declare pos bigint;
declare text_len bigint;
declare delimiter_len smallint;
declare part_begin bigint;
begin
    if (coalesce(text, '') = '') then exit;

    pos = 0;
    idx = 0;
    part_begin = 1;
    text_len = char_length(text);
    delimiter_len = char_length(delimiter);

    while (pos <= text_len) do
    begin
        pos = pos + 1;
        if ((substring(text from pos for delimiter_len) = delimiter) or (pos = text_len)) then
        begin
            if (pos = text_len and (substring(text from pos for delimiter_len) <> delimiter))
                then pos = pos + 1;

            part = substring(text from part_begin for pos - part_begin);
            part = iif(trim_part = 1, trim(part), part);
            part_begin = pos + delimiter_len;

            idx = idx + 1;
            suspend;
        end
    end
end^

set term ; ^