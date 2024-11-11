execute block
returns (
    seq_name varchar(31)
    , seq_value bigint
)
as
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    for select
            rdb$generator_name
        from rdb$generators
        where coalesce(RDB$SYSTEM_FLAG, 0) = 0
            -- and rdb$generator_name = upper(trim(:seq_name_filter)))
        into seq_name
    do
    begin
        seq_value = null;
        execute statement 'select gen_id(' || seq_name || ', 0) from rdb$database' into seq_value;
        suspend;
    end
end