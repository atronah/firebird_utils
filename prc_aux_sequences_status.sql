set term ^ ;

create or alter procedure aux_sequences_status(
    seq_name_filter varchar(31) = null
)
returns (
    seq_name varchar(31)
    , seq_value bigint
)
as
begin
    for select
            rdb$generator_name
        from rdb$generators
        where coalesce(RDB$SYSTEM_FLAG, 0) = 0
            and (:seq_name_filter is null or rdb$generator_name = upper(trim(:seq_name_filter)))
        into seq_name
    do
    begin
        seq_value = null;
        execute statement 'select gen_id(' || seq_name || ', 0) from rdb$database' into seq_value;
        suspend;
    end
end^

set term ; ^