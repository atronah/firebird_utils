set term ^ ;

-- Parses all attributes from text
create or alter procedure aux_xml_get_attributes(
    attrubutes blob sub_type text
)
returns(
    alias varchar(1024)
    , name varchar(1024)
    , val varchar(16000)
)
as
declare pos bigint;
declare eq_pos bigint;
declare colon_pos bigint;
declare end_pos bigint;
declare len bigint;
begin
    pos = 1;
    len = char_length(attributes);
    
    while (pos < len) do
    begin
        eq_pos = position('=', attributes, pos);
        
        if (eq_pos is null) 
            then break;
 
        colon_pos = position('=', attributes, pos);
        if (colon_pos between pos and eq_pos) then
        begin
            alias = trim(substring(attributes from pos for colon_pos - pos));
            pos = colon_pos + 1;
        end
        
        name = trim(substring(attributes from pos for eq_pos - pos));
        pos = position('"', attributes, eq_pos + 1) + 1;
        end_quote_pos = position('"', attributes, pos);
        val = trim(substring(attributes from pos for end_quote_pos - pos));
        
        pos = end_quote_pos;
    end
end^

set term ; ^


comment on procedure aux_xml_get_attributes is '';
comment on parameter aux_xml_get_attributes.attributes is '';
