set term ^ ;

create or alter function auxf_xml_unescape(
    source_text blob sub_type text
)
returns blob sub_type text
as
declare result blob sub_type text;
declare pos bigint;
declare escaped_char varchar(32);
declare escaped_char_hex_code varchar(32);
declare escaped_char_ascii_code varchar(32);
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    -- todo: add full support named escaped characters and decimal escaped
    -- (now supports only some named and all ascii hex)

    result = source_text;

    if (result not containing '&')
        then return result;


    result = replace(result, '&quot;', '"');
    result = replace(result, '&apos;', '''');
    result = replace(result, '&lt;', '<');
    result = replace(result, '&gt;', '>');
    result = replace(result, '&amp;', '&');

    -- look up for `&...;` substrings
    pos = position('&', result);
    while (pos > 0) do
    begin

        -- process escaped by hex codes (like `&#xAA;`)
        if (lower(substring(result from pos + 2 for 1)) = 'x' -- start of hex code
            and substring(result from pos + 5 for 1) = ';' -- end of escaped char
        ) then
        begin
            escaped_char = substring(result from pos for 6);
            escaped_char_hex_code = upper(substring(escaped_char from 4 for 2));
            if (upper(escaped_char_hex_code) similar to '[0-9A-F]{2}') then
            begin
                escaped_char_ascii_code = 16 * cast(iif(left(escaped_char_hex_code, 1) between 'A' and 'F'
                                                        -- `A` has ascii code `65`, `B` - `66`, ..., `F` - `70` etc.
                                                        , ascii_val(left(escaped_char_hex_code, 1)) - 55
                                                        , left(escaped_char_hex_code, 1))
                                                    as smallint)
                                          + cast(iif(right(escaped_char_hex_code, 1) between 'A' and 'F'
                                                      , ascii_val(right(escaped_char_hex_code, 1)) - 55
                                                      , right(escaped_char_hex_code, 1))
                                                  as smallint);
                result = replace(result, escaped_char, ascii_char(escaped_char_ascii_code));
                when any do
                begin
                end
            end
        end
        pos = position('&', result, pos + 1);
    end

    return result;
end^

set term ; ^

comment on function auxf_xml_unescape is 'unEscapes some special characters, i.e. replace escaped chars like `&#xAA;` or `&quot;` to characters itself';