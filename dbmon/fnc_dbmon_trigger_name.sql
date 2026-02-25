set term ^ ;
create or alter function dbmon_trigger_name(
    table_name type of column dbmon_tracked_field.table_name
    , trigger_name_suffix varchar(31) = null
    , available_name_legth bigint = null
)
returns varchar(255)
as
declare name_gen_attempt bigint;
declare trigger_name_prefix varchar(32);
declare trigger_name varchar(255);
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master/dbmon

    trigger_name_prefix = upper('dbmon');
    trigger_name_suffix = upper(coalesce(trigger_name_suffix, 'auid'));

    available_name_legth = coalesce(available_name_legth, 31) - char_length(trigger_name_prefix || trigger_name_suffix || '__');
    table_name = replace(table_name, '''', '''''');


    trigger_name = (select trim(rdb$trigger_name)
                    from rdb$triggers
                    where rdb$relation_name = :table_name
                        and rdb$trigger_name starts with (:trigger_name_prefix || '_')
                        and right(trim(rdb$trigger_name), char_length(:trigger_name_suffix) + 1) = '_' || :trigger_name_suffix);
    if (trigger_name is null) then
    begin
        trigger_name = trigger_name_prefix
                        || '_' || left(table_name, available_name_legth)
                        || '_' || trigger_name_suffix;
    end

    return trigger_name;
end^

set term ; ^