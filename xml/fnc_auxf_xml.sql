set term ^ ;

create or alter function auxf_xml(
    name varchar(64)
    , val blob sub_type text
    , vtype varchar(16) = null
    , req smallint = null
    , attr blob sub_type text = null
    , xsi_alias varchar(32) = null
)
returns blob sub_type text
deterministic
as
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    return (select node from aux_xml_node(:name, :val, :vtype, :req, :attr, :xsi_alias));
end^

set term ; ^

comment on function auxf_xml is 'Creates xml node with specified value (of scpecified type) with passed attributes (uses procedure `aux_xml_node`)';

comment on parameter auxf_xml.name is 'Name of xml node';
comment on parameter auxf_xml.val is 'Value of xml node';
comment on parameter auxf_xml.vtype is 'Type of value for xml node in following structure: `<type>[:<format>]`, in which
- `<type>` - name of type (supported values: `node`, `str`, `int`, `bool`, `date`, `time`, `datetime`),
- `<format>` - formatting mode for value; supported values depends on <type>:
    - for `datetime` type following formats are available:
        - `0` - puts date and time in xml like `YYYY-MM-DDThh:mm:ss` (with `T` between date and time)
        - `1` - puts date and time in xml like `YYYY-MM-DD hh:mm:ss` (with space ` ` between date and time)
    - for `str` type following formats are available:
        - `escaped` - all following characters will be escaped:
            - 13 - CR (carriage return) - will be replaced by `&#13;`
            - 10 - LF (NL line feed, new line) - will be replaced by `&#10;`
            - 28 - FS (file separator) - will be removed
            - 29 - GS (group separator) - will be removed
            - 30 - RS  (record separator) - will be removed
            - 31 - US  (unit separator) - will be removed
        - ';
comment on parameter auxf_xml.req is 'Requiring status of xml node:
- null/0 (default) - node is skipping if its value is empty or null
- 1 - puts empty singular node (`<a />`) if its value is empty or null
- 2 - puts attribute `nil="true"` (from http://www.w3.org/2001/XMLSchema-instance namespace) if its value is null';
comment on parameter auxf_xml.attr is 'Attributes of xml node in raw format (will be put into xml as is';
comment on parameter auxf_xml.xsi_alias is 'Alias for `XMLSchema-instance` namespace (http://www.w3.org/2001/XMLSchema-instance namespace) which will be used for nil attribute, see `req` input parameter description; default: `xsi`)';