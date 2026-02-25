set term ^ ;
create or alter trigger dbmon_tracked_field_ad
    active
    after delete
    on dbmon_tracked_field
as
declare trigger_name type of column rdb$triggers.rdb$trigger_name;
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master/dbmon

    -- do nothing if exists another rule for the same table
    if (exists(select * from dbmon_tracked_field where table_name = old.table_name))
        then exit;

    trigger_name = dbmon_trigger_name(old.table_name, 'auid');
    while (exists(select t.rdb$trigger_name
                    from rdb$triggers as t
                    where t.rdb$relation_name = old.table_name
                        and t.rdb$trigger_name = :trigger_name
                        and coalesce(t.rdb$trigger_inactive, 0) = 0)
    ) do
    begin
        execute statement 'alter trigger ' || trim(trigger_name) || ' inactive;';
    end
end^

set term ; ^

comment on trigger dbmon_tracked_field_ad is 'Trigger to disable dbmon triggers on tables which was removed from  `dbmon_tracked_field`.
See https://github.com/atronah/firebird_utils/tree/master/dbmon for details.';