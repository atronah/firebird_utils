set term ^ ;

create or alter function auxf_xml_attr(
    name varchar(64),
    val varchar(1204)
)
returns blob sub_type text
as
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    val = replace(val, '&', '&amp;');
    val = replace(val, '<', '&lt;');
    val = replace(val, '>', '&gt;');
    val = replace(val, '"', '&quot;');
    val = replace(val, ascii_char(13), '&#13;'); -- 13 - CR (carriage return)
    val = replace(val, ascii_char(10), '&#10;'); -- 10 - LF (NL line feed, new line)
    val = replace(val, ascii_char(28), ''); -- 28 - FS (file separator)
    val = replace(val, ascii_char(29), ''); -- 29 - GS (group separator)
    val = replace(val, ascii_char(30), ''); -- 30 - RS  (record separator)
    val = replace(val, ascii_char(31), ''); -- 31 - US  (unit separator)

    return name || '="' || val || '" ';
end^

set term ; ^


comment on function auxf_xml_attr is 'Creates (encode) attribute of xml node with escaping special characters';

comment on parameter auxf_xml_attr.name is 'Name of attribute for xml node';
comment on parameter auxf_xml_attr.val is 'Value of attribute for xml node';
