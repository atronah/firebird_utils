set term ^ ;

create or alter procedure aux_json_node(
    name varchar(255) -- name of node
    , val blob sub_type text -- value of node
    , value_type varchar(16) = null -- type of value `<type>[:<format>]`, where `<type>` - name of type (str, obj or node, list, num, bool, date, time, datetime), and `<format>` - formatting way (for `datetime` two fomats are available : `0` - `YYYY-MM-DDThh:mm:ss`, `1` - `YYYY-MM-DD hh:mm:ss`)
    , required smallint = null -- requirement of node: 0 - no node (empty string) for null values; 1 - empty node with `null` as value; 2 - empty node with empty value (for `obj` - `{}`, for `list` - `[]`, for `str` - `""`);
    , add_delimiter smallint = null -- if distinct from zero comma will be put after node
    , formatting smallint = null -- if distinct from zero indents will be put in resulted node
)
returns (
    node blob sub_type text
)

as
declare pos bigint;
declare format_str varchar(32);
declare val_datetime timestamp;
declare indent varchar(4) = '    ';
-- constants
-- -- aux_json_node.required input parameter
declare OPTIONAL bigint = 0; -- 0 - no node (empty string) for null values;
declare REQUIRED_AS_NULL bigint = 1; -- 1 - empty node with `null` as value;
declare REQUIRED_AS_EMPTY bigint = 2; -- 2 - empty node with empty value (for `obj` - `{}`, for `list` - `[]`, for `str` - `""`);
-- -- aux_json_node.human_readable input parameter
declare NO_FORMATTING smallint = 0;
declare HUMAN_READABLE_FORMATTING smallint = 1;
-- -- aux_json_node.add_delimiter input parameter
declare NO_DELIMITER smallint = 0; -- 0 - without comma after json node
declare WITH_DELIMITER smallint = 1; -- 0 - witht comma after json node
-- -- other
declare SPACE_DUMMY varchar(32) = '<<FBUTILS_JSON_SPACE>>'; -- to substitute it to space after formating and trimming
declare endl varchar(2) = '
';
begin
    node = '';

    value_type = coalesce(value_type, 'str');
    required = coalesce(required, OPTIONAL);
    formatting = coalesce(formatting, NO_FORMATTING);
    add_delimiter = coalesce(add_delimiter, NO_DELIMITER);

    if (formatting = NO_FORMATTING) then
    begin
        endl = '';
        indent = '';
    end

    value_type = lower(value_type);

    pos = position(':' in value_type);
    if (pos > 0) then
    begin
        format_str = substring(value_type from pos + 1);
        value_type = substring(value_type from 1 for pos - 1);
    end

    if (value_type = 'node')
        then value_type = 'obj';


    if (val is null and required = REQUIRED_AS_EMPTY) then
    begin
        val = case value_type
                    when 'obj' then '{}'
                    when 'list' then '[]'
                    else ''
                end;
    end

    if (value_type in ('obj', 'list')) then
    begin
        if (required = :OPTIONAL
                and val similar to '[[:WHITESPACE:]]*'
        ) then val = null;

        if (formatting = HUMAN_READABLE_FORMATTING and val containing endl)
            then select list(:indent || :indent || part, :endl)
                    from aux_split_text(:val, :endl, 0)
                    where part <> ''
                    into val;

        -- trailing last white spaces and comma (instead of `val = trim(trim(trailing ',' from val));`)
        pos = char_length(val);
        while (pos > 0) do
        begin
            if (substring(val from pos for 1)
                    in (ASCII_CHAR(13), ASCII_CHAR(10), ASCII_CHAR(32), ',')
            ) then
            begin
                val = left(val, pos - 1) || substring(val from pos + 1);
                pos = pos - 1;
            end
            else break;
        end

        val = case value_type
                    when 'obj' then iif(val similar to '[[:WHITESPACE:]]*&{%' escape '&'
                                        , val
                                        , '{' || endl || indent || val || endl || '}')
                    when 'list' then iif(val similar to '[[:WHITESPACE:]]*&[%' escape '&'
                                        , val
                                        , '[' || endl || val || endl || ']')
                end;
    end
    else if (value_type = 'bool') then
    begin
        val = trim(iif(upper(trim(val)) in ('', '0', 'FALSE', 'F'), 'false', 'true'));
    end
    else if (value_type in ('date', 'datetime')) then
    begin
        val_datetime = cast(val as timestamp);
        val = '"' || extract(year from val_datetime)
                    || '-' || lpad(extract(month from val_datetime), 2, '0')
                    || '-' || lpad(extract(day from val_datetime), 2, '0')
                    || iif(value_type = 'datetime'
                            , iif(format_str = '1', ' ', 'T')
                                || lpad(extract(hour from val_datetime), 2, '0')
                                || ':' || lpad(extract(minute from val_datetime), 2, '0')
                                || ':' || lpad(trunc(extract(second from val_datetime)), 2, '0')
                            , '')
                || '"';
    end
    else if (value_type = 'time') then
    begin
        val = '"' || case
                        when val similar to '[0-9]{4}$-[0-9]{2}$-[0-9]{2}[ T]?[0-9]{2}:[0-9]{2}:[0-9]{2}(.[0-9]+)?' escape '$'
                            then left(cast(cast(val as timestamp) as time), 8)
                        when val similar to '[0-9]{1,2}:[0-9]{1,2}(:[0-9]{1,2})?(.[0-9]+)?'
                            then left(cast(val as time), 8)
                        else null
                    end
            || '"';
    end
    else if (value_type = 'num') then
    begin
        val = iif(val similar to '&-?([1-9][0-9]*|0)(.[0-9]*)?((e|E)(&+|&-)?[0-9]*)?' escape '&'
                    , val
                    , null);
    end
    else val = '"' || replace(val, '"', '\"') || '"';

    if (val is not null or required > 0) then
    begin
        node = iif(coalesce(name, '') = ''
                    , ''
                    , '"' || name || '":' || trim(iif(formatting > NO_FORMATTING, SPACE_DUMMY, '')))
            || coalesce(val, 'null')
            || iif(add_delimiter > 0, ',' || trim(iif(formatting > NO_FORMATTING, SPACE_DUMMY, '')) || endl, '');
    end

    node = replace(node, SPACE_DUMMY, ' ');

    suspend;
end^

set term ; ^


comment on procedure aux_json_node is 'Returns json node';
comment on parameter aux_json_node.name is 'name of node';
comment on parameter aux_json_node.val is 'value of node';
comment on parameter aux_json_node.value_type is 'type of value `<type>[:<format>]`, where `<type>` - name of type (str, obj or node, list, num, bool, date, time, datetime), and `<format>` - formatting way (for `datetime` two fomats are available : `0` - `YYYY-MM-DDThh:mm:ss`, `1` - `YYYY-MM-DD hh:mm:ss`)';
comment on parameter aux_json_node.required is 'requirement of node:
- 0 - no node (empty string) for null values;
- 1 - empty node with `null` as value;
- 2 - empty node with empty value (for `obj` - `{}`, for `list` - `[]`, for `str` - `""`);';
comment on parameter aux_json_node.formatting is 'if distinct from zero indents will be put in resulted node';
comment on parameter aux_json_node.add_delimiter is 'if distinct from zero comma will be put after node';

