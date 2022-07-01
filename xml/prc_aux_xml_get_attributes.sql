set term ^ ;

-- Parses all attributes from text
create or alter procedure aux_xml_get_attributes(
    xml_openning_tag blob sub_type text
)
returns(
    alias varchar(1024)
    , name varchar(1024)
    , val varchar(16000)
    --
    , name_pattern varchar(1024)
    , aliased_name_pattern varchar(1024)
    , attribute_pattern varchar(1024)
    , attribute_list_pattern varchar(1024)
)
as
declare attributes tblob;
declare pos bigint;
declare len bigint;
declare c varchar(1);
declare state smallint;
-- Constants
declare STATE_NONE smallint = 0;
declare STATE_NAME smallint = 1;
declare STATE_WS_BEFORE_EQUAL smallint = 2;
declare STATE_EQUAL smallint = 3;
declare STATE_WS_AFTER_EQUAL smallint = 1;
declare STATE_VALUE smallint = 5;
declare STATE_UNEXPECTED smallint = 6;
begin
    -- create exception ERROR 'ERROR';

    name_pattern = '[a-zA-Zа-яА-ЯёЁ][a-zA-Zа-яА-ЯёЁ0-9_]*'; -- name pattern
    aliased_name_pattern = '(' || :name_pattern || ':)*' || :name_pattern; -- aliased name pattern
    attribute_pattern = :aliased_name_pattern || '\s*=\s*"[^"]*"'; -- attribute pattern
    attribute_list_pattern = '(\s*' || :attribute_pattern || ')+'; -- attributes pattern

    attributes = (select trim(match) from mds_aux_regexp_search(:attribute_list_pattern, :xml_openning_tag, 1));

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
comment on parameter aux_xml_get_attributes.xml_openning_tag is '';
