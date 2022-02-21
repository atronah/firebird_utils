set term ^ ;

create or alter procedure mds_json_node(
    name varchar(255) -- name of node
    , val blob sub_type text -- value of node
    , value_type varchar(16) = 'str' -- type of value `<type>[:<format>]`, where `<type>` - name of type (str, obj or node, list, num, bool, date, time, datetime), and `<format>` - formatting way (for `datetime` two fomats are available : `0` - `YYYY-MM-DDThh:mm:ss`, `1` - `YYYY-MM-DD hh:mm:ss`)
    , required smallint = 0 -- requirement of node: 0 - empty string for node with null value, 1 - node with empty value
    , human_readable smallint = 0 -- if distinct from zero indents will be put in resulted node
    , add_delimiter smallint = 0 -- if distinct from zero comma will be put after node
)
returns (
    node blob sub_type text
)

as
declare indent varchar(4) = '    ';
declare endl varchar(2) = '
';
begin
    node = '';

    if (human_readable = 0) then
    begin
        endl = '';
        indent = '';
    end

    if (value_type = 'node')
        then value_type = 'obj';

    if (value_type in ('obj', 'list')) then
    begin
        if (human_readable = 1)
            then select list(:indent || part, :endl)
                    from aux_split_text(:val, :endl, 0)
                    where part <> ''
                    into val;
        val = trim(trailing ',' from val);
    end

    if (val is not null or required > 0) then
    begin
        val = coalesce(val, '');

        node = iif(coalesce(name, '') = ''
                    , ''
                    , '"' || name || '": ')
            || case value_type
                    when 'obj'
                        then iif(trim(val) starts with '{'
                                , val
                                , '{' || endl || val || endl || '}')
                    when 'list'
                        then '[' || endl || val || endl || ']'
                    when 'bool'
                        then '"' || trim(iif(upper(trim(val)) in ('', '0', 'FALSE', 'F'), 'false', 'true')) || '"'
                    when 'date'
                        then '"' || (select string from mds_aux_format_date(cast(left(:val, 10) as date), 'yyyy-MM-dd')) || '"'
                    when 'datetime'
                        then '"' || (select string
                                        from mds_aux_format_date(iif(:val similar to '[0-9]{4}$-[0-9]{2}$-[0-9]{2}' escape '$'
                                                                    , cast(cast(:val as date) as timestamp)
                                                                    , cast(:val as timestamp))
                                                                , 'yyyy-MM-ddThh:mm:ss'))
                                || '"'
                    when 'time'
                        then '"' || (select string
                                        from mds_aux_format_date(iif(:val similar to '[0-9]{1,2}:[0-9]{1,2}(:[0-9]{1,2})?(.[0-9]+)?'
                                                                    , '1970-01-01 ' || :val
                                                                    , :val)
                                                                , 'hh:mm:ss'))
                                || '"'
                    when 'str' then '"' || replace(val, '"', '\"') || '"'
                    else val
                end
            || iif(add_delimiter > 0, ',' || endl, '');
    end

    suspend;
end^

set term ; ^


comment on procedure mds_json_node is 'Returns json node';
comment on parameter mds_json_node.name is 'name of node';
comment on parameter mds_json_node.val is 'value of node';
comment on parameter mds_json_node.value_type is 'type of value `<type>[:<format>]`, where `<type>` - name of type (str, obj or node, list, num, bool, date, time, datetime), and `<format>` - formatting way (for `datetime` two fomats are available : `0` - `YYYY-MM-DDThh:mm:ss`, `1` - `YYYY-MM-DD hh:mm:ss`)';
comment on parameter mds_json_node.required is 'requirement of node: 0 - empty string for node with null value, 1 - node with empty value';
comment on parameter mds_json_node.human_readable is 'if distinct from zero indents will be put in resulted node';
comment on parameter mds_json_node.add_delimiter is 'if distinct from zero comma will be put after node';

