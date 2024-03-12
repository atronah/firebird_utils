set term ^ ;

create or alter procedure aux_json_node(
    name varchar(255) -- name of node
    , val blob sub_type text -- value of node
    , value_type varchar(16) = null -- see comment for parameter
    , required smallint = null -- see comment for parameter
    , add_delimiter smallint = null -- see comment for parameter
    , formatting smallint = null -- see comment for parameter
    , tz_hour smallint = null
    , tz_min smallint = null
)
returns (
    node blob sub_type text
)

as
declare pos bigint;
declare val_length bigint;
declare format_str varchar(32);
declare val_datetime timestamp;
declare val_tmp blob sub_type text;
declare indent varchar(4) = '    ';
-- constants
-- -- aux_json_node.required input parameter
declare OPTIONAL bigint = 0; -- 0 - no node (empty string) for null values;
declare REQUIRED_AS_NULL bigint = 1; -- 1 - empty node with `null` as value;
declare REQUIRED_AS_EMPTY bigint = 2; -- 2 - empty node with empty value (for `obj` - `{}`, for `array`/`list` - `[]`, for `str` - `""`);
-- -- aux_json_node.human_readable input parameter
declare NO_FORMATTING smallint = 0;
declare HUMAN_READABLE_FORMATTING smallint = 1;
-- -- aux_json_node.add_delimiter input parameter
declare NO_DELIMITER smallint = 0; -- 0 - without comma after json node
declare WITH_DELIMITER smallint = 1; -- 0 - witht comma after json node
-- -- other
declare endl varchar(2) = '
';
begin
    -- WARNING:
    -- if your database has WIN1251 encofing, you should create this procedure in that database only in WIN1251 connection
    -- (I mean, use `isql -ch win1251 your_database -i prc_aux_json_node.sql`)
    -- otherwise (if you create procedure in utf8 charset for win1251 databse) you could get error
    -- `Cannot transliterate character between character sets` when you use this procedure
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

    value_type = case value_type
                    when 'node' then 'obj'
                    when 'list' then 'array'
                    else value_type
                end;

    if (val is null and required = REQUIRED_AS_EMPTY) then
    begin
        val = case value_type
                    when 'obj' then '{}'
                    when 'array' then '[]'
                    else ''
                end;
    end

    if (value_type in ('obj', 'array')) then
    begin
        if (required = :OPTIONAL
                and val similar to '[[:WHITESPACE:]]*'
        ) then val = null;

        val_length = char_length(val);
        if (formatting = HUMAN_READABLE_FORMATTING and val_length < 32000) then
        begin
            val_tmp = '';

            while (val containing ENDL) do
            begin
                val_tmp = val_tmp
                            || iif(val_tmp > '', indent, '')
                            || substring(val from 1 for position(:ENDL in val) + char_length(:ENDL) - 1);
                val = substring(val from position(:ENDL in val) + char_length(:ENDL));
            end
            val = val_tmp || iif(val > '', indent, '') || val;
            val_length = char_length(val_32k);
        end

        -- trailing last white spaces and comma (instead of `val = trim(trim(trailing ',' from val));`)
        pos = val_length;
        while (substring(val from pos for 1) in (ASCII_CHAR(13), ASCII_CHAR(10), ASCII_CHAR(32), ',')) do
        begin
            pos = pos - 1;
        end

        if (pos < val_length)
            then val = left(val, pos);

        val = case value_type
                    when 'obj' then iif(val similar to '[[:WHITESPACE:]]*&{%' escape '&'
                                        , val
                                        , '{' || endl || indent || val || endl || '}')
                    when 'array' then iif(val similar to '[[:WHITESPACE:]]*&[%' escape '&'
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
                            || trim(iif(format_str = '2'
                                        , iif(tz_hour is not null
                                                , iif(tz_hour > 0, '+', '-')
                                                    || lpad(abs(tz_hour), 2, '0')
                                                    || ':'
                                                    || lpad(coalesce(tz_min, 0), 2, '0')
                                                , 'Z')
                                        , ''))
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
    else
    begin
        val = '"'
                -- escaping some characters (based on info from https://www.tutorialspoint.com/json_simple/json_simple_escape_characters.htm)
                || replace(replace(val
                        , trim('\ '), trim('\\ ')) -- extra space + trim used to fix problems with highlighting in some text editors
                        , '"', '\"')
            || '"';
    end

    if (val is not null or required > 0) then
    begin
        node = iif(coalesce(name, '') = ''
                    , ''
                    , '"' || name || '":' || iif(formatting > NO_FORMATTING, ' ', trim('')))
            || coalesce(val, 'null')
            || iif(add_delimiter > 0, ',' || endl, '');
    end

    suspend;
end^

set term ; ^


comment on procedure aux_json_node is 'Returns json node';
comment on parameter aux_json_node.name is 'name of node';
comment on parameter aux_json_node.val is 'value of node';
comment on parameter aux_json_node.value_type is 'type of value `<type>[:<format>]`
- `<type>` - name of type, supported values:
    - `str` - text value (within quotas)
    - `obj` or `node` - json object (within `{` and `}`)
    - `array` or `list` - json array  (within `[` and `]`)
    - `num` - json number
    - `bool` - boolean value (`true` or `false`)
    - `date` - date value
    - `time` - time value
    - `datetime` - date + time value
- `<format>` - formatting way
    - for `datetime` available fomats:
        - `0` - `YYYY-MM-DDThh:mm:ss`
        - `1` - `YYYY-MM-DD hh:mm:ss`
        - `2` - datetime in ISO with timezone from input parameters `tz_hour` and `tz_min`
        (`YYYY-MM-DD hh:mm:ss+TH:TM` or `YYYY-MM-DD hh:mm:ss-TH:TM` or `YYYY-MM-DD hh:mm:ssZ`)
';
comment on parameter aux_json_node.required is 'requirement of node:
- 0 - no node (empty string) for null values;
- 1 - empty node with `null` as value;
- 2 - empty node with empty value (for `obj` - `{}`, for `array`/`list` - `[]`, for `str` - `""`);';
comment on parameter aux_json_node.add_delimiter is 'if distinct from zero comma will be put after node';
comment on parameter aux_json_node.formatting is 'if distinct from zero indents will be put in resulted node';

