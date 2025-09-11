set term ^ ;

create or alter procedure aux_xml_node(
    name varchar(64)
    , val blob sub_type text
    , vtype varchar(16) = null
    , req smallint = null
    , attr blob sub_type text = null
    , xsi_alias varchar(32) = null
)
returns(
    node blob sub_type text
)
as
declare pos bigint;
declare format_str varchar(32);
declare val_datetime timestamp;
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    vtype = coalesce(vtype, 'str');
    req = coalesce(req, 0);
    attr = coalesce(attr, '');
    xsi_alias = coalesce(xsi_alias, 'xsi');

    attr = coalesce(attr, '');
    xsi_alias = iif(coalesce(trim(xsi_alias), '') = '', 'xsi', xsi_alias);

    vtype = lower(vtype);

    -- Processing passed format for value type
    pos = position(':' in vtype);
    if (pos > 0) then
    begin
        format_str = substring(vtype from pos + 1);
        vtype = substring(vtype from 1 for pos - 1);
    end

    -- Processing passed type of value
    if (vtype in ('date', 'datetime')) then
    begin
        val_datetime = cast(val as timestamp);
        val = extract(year from val_datetime)
                        || '-' || lpad(extract(month from val_datetime), 2, '0')
                        || '-' || lpad(extract(day from val_datetime), 2, '0')
                        || iif(vtype = 'datetime'
                                , iif(format_str = '1', ' ', 'T')
                                    || lpad(extract(hour from val_datetime), 2, '0')
                                    || ':' || lpad(extract(minute from val_datetime), 2, '0')
                                    || ':' || lpad(trunc(extract(second from val_datetime)), 2, '0')
                                , '');
    end
    else if (vtype in ('time')) then
    begin
        val = case
                    when val similar to '[0-9]{4}$-[0-9]{2}$-[0-9]{2}[ T]?[0-9]{2}:[0-9]{2}:[0-9]{2}(.[0-9]+)?' escape '$'
                        then left(cast(cast(val as timestamp) as time), 8)
                    when val similar to '[0-9]{1,2}:[0-9]{1,2}(:[0-9]{1,2})?(.[0-9]+)?'
                        then left(cast(val as time), 8)
                    else null
                end;
    end
    else if (vtype in ('bool')) then
    begin
        if (val is not null)
            then val = trim(iif(upper(trim(val)) in ('', '0', 'FALSE', 'F'), 'false', 'true'));
    end
    else if (vtype in ('str')) then
    begin
        val = replace(val, '&', '&amp;');
        val = replace(val, '<', '&lt;');
        val = replace(val, '>', '&gt;');

        if (format_str = 'escaped') then
        begin
            -- I am not sure that bellow replaces are needed (were inherited from other code)
            -- that's why it was splitted into another subtype `str:escaped`
            val = replace(val, ascii_char(13), '&#13;'); -- 13 - CR (carriage return)
            val = replace(val, ascii_char(10), '&#10;'); -- 10 - LF (NL line feed, new line)
            val = replace(val, ascii_char(28), ''); -- 28 - FS (file separator)
            val = replace(val, ascii_char(29), ''); -- 29 - GS (group separator)
            val = replace(val, ascii_char(30), ''); -- 30 - RS  (record separator)
            val = replace(val, ascii_char(31), ''); -- 31 - US  (unit separator)
        end
    end

    attr = coalesce(attr, '');
    -- nil-атрибут
    if(req = 2 and val is null)
        then attr = attr
                        -- space between previous attributes and nil attribute
                        || ' '
                        -- nil attribute itself
                        || xsi_alias || ':nil="' || 'true' || '"';

    node = iif(coalesce(val, '') = '' and req = 0
                , ''
                , '<' || name
                    -- attribute
                    || iif(attr > '', ' ' || trim(attr), '')
                    -- closing xml opening tag
                    || iif(coalesce(val, '') = ''
                            , '/>' -- empty node (`<a />`)
                            , '>' -- node with value (`<a>v</a>`)
                                -- newline characters for `node` type
                                || iif(vtype in ('node'), ascii_char(10), '')
                                -- value of node
                                || val
                                -- clossing tag
                                || '</' || name || '>')
                    -- newline characters
                    || ascii_char(10)
                );
    suspend;
end^

set term ; ^


comment on procedure aux_xml_node is 'Creates xml node with specified value (of scpecified type) with passed attributes';

comment on parameter aux_xml_node.name is 'Name of xml node';
comment on parameter aux_xml_node.val is 'Value of xml node';
comment on parameter aux_xml_node.vtype is 'Type of value for xml node in following structure: `<type>[:<format>]`, in which
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
comment on parameter aux_xml_node.req is 'Requiring status of xml node:
- null/0 (default) - node is skipping if its value is empty or null
- 1 - puts empty singular node (`<a />`) if its value is empty or null
- 2 - puts attribute `nil="true"` (from http://www.w3.org/2001/XMLSchema-instance namespace) if its value is null';
comment on parameter aux_xml_node.attr is 'Attributes of xml node in raw format (will be put into xml as is';
comment on parameter aux_xml_node.xsi_alias is 'Alias for `XMLSchema-instance` namespace (http://www.w3.org/2001/XMLSchema-instance namespace) which will be used for nil attribute, see `req` input parameter description; default: `xsi`)';
comment on parameter aux_xml_node.node is 'Resulting xml node';