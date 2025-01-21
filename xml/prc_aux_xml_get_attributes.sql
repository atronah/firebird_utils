set term ^ ;

-- Parses all xml attributes from string
create or alter procedure aux_xml_get_attributes(
    attributes blob sub_type text
)
returns(
    alias varchar(1024)
    , name varchar(1024)
    , val varchar(16000)
    , full_attribute varchar(16000)
)
as
declare pos bigint;
declare eq_pos bigint;
declare colon_pos bigint;
declare end_quote_pos bigint;
declare len bigint;
declare allowed_name_symbols varchar(1024);
begin
    allowed_name_symbols = 'abcdefghijklmnopqrstuvwxyz'
                            || 'абвгдеёжзиклмнопрстуфхцчшщъыьэюя';
    allowed_name_symbols = lower(allowed_name_symbols)
                            || upper(allowed_name_symbols)
                            || '_';

    pos = 1;
    len = char_length(attributes);

    while (pos between 1 and len) do
    begin
        eq_pos = position('=', attributes, pos);

        if (coalesce(eq_pos, -1) <= 0)
            then break;

        colon_pos = position(':', attributes, pos);
        if (colon_pos between pos and eq_pos) then
        begin
            -- if (pos < 0 or (colon_pos - pos) < 0) then execute procedure raise_exception('oops: @1, @2, @3', 99, :pos, :colon_pos);
            alias = trim(substring(attributes from pos for colon_pos - pos));
            pos = colon_pos + 1;
        end
        else alias = null;

        -- if (pos < 0 or (eq_pos - pos) < 0) then execute procedure raise_exception('oops2: @1, @2, @3', 99, :pos, :eq_pos);
        name = trim(substring(attributes from pos for eq_pos - pos));
        pos = position('"', attributes, eq_pos + 1) + 1;
        end_quote_pos = position('"', attributes, pos);
        val = trim(substring(attributes from pos for end_quote_pos - pos));

        pos = end_quote_pos + 1;

        if (alias > '')
            then alias = (select result from aux_strip_text(:alias, :allowed_name_symbols, 1));
        name = (select result from aux_strip_text(:name, :allowed_name_symbols, 1));

        full_attribute = trim(coalesce(alias || ':', '')) || name || '="' || val || '"';
        suspend;
    end
end^

set term ; ^


comment on procedure aux_xml_get_attributes is 'Parses all xml attributes from string';
comment on parameter aux_xml_get_attributes.attributes is 'input string with attributes separated by space';
