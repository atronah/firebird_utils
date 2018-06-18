set term ^ ;

create or alter procedure mds_json_node(
    name varchar(255)
    , val blob sub_type text
    , value_type varchar(16) = 'str'
    , required smallint = 0
    , human_readable smallint = 0
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
    else if (value_type in ('node', 'list')) then
    begin
        select list(:indent || part, :endl) from aux_split_text(:val, :endl, 0) into val;
    end



    if (val is not null or required > 0) then
    begin
        val = coalesce(val, '');

        node = iif(coalesce(name, '') = ''
                    , ''
                    , '"' || name || '": ')
            || case value_type
                    when 'node'
                        then '{' || endl || val || endl || '}'
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
                    else '"' || val || '"'
                end;
    end

    suspend;
end^

set term ; ^