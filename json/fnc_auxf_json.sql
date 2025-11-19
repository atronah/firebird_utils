set term ^ ;

create or alter function auxf_json(
    name varchar(255) -- name of node
    , val blob sub_type text -- value of node
    , value_type varchar(16) = null -- see comment for parameter
    , required smallint = null -- see comment for parameter
    , add_delimiter smallint = null -- see comment for parameter
    , formatting smallint = null -- see comment for parameter
    , tz_hour smallint = null
    , tz_min smallint = null
)
returns blob sub_type text
deterministic
as
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    return (select node from aux_json_node(:name, :val, :value_type, :required, :add_delimiter, :formatting, :tz_hour, :tz_min));
end^

set term ; ^

comment on function auxf_json is 'Creates json node with specified value (of scpecified type) with passed attributes (uses procedure `aux_json_node`)';

comment on parameter auxf_json.name is 'name of node';
comment on parameter auxf_json.val is 'value of node';
comment on parameter auxf_json.value_type is 'type of value `<type>[:<format>]`
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
comment on parameter auxf_json.required is 'requirement of node:
- 0 - no node (empty string) for null values;
- 1 - empty node with `null` as value;
- 2 - empty node with empty value (for `obj` - `{}`, for `array`/`list` - `[]`, for `str` - `""`);';
comment on parameter auxf_json.add_delimiter is 'if distinct from zero comma will be put after node';
comment on parameter auxf_json.formatting is 'if distinct from zero indents will be put in resulted node';

