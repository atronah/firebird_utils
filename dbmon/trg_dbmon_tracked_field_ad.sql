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

    -- disable tracking trigger if not exists another rule for the same table
    -- (because one common tracking trigger is used for all rules)
    if (not exists(select *
                    from dbmon_tracked_field as tf
                    where tf.table_name = old.table_name
                        and tf.field_name is distinct from old.field_name)
    ) then
    begin
        trigger_name = dbmon_trigger_name(old.table_name, 'auid');

        if (exists(select t.rdb$trigger_name
                        from rdb$triggers as t
                        where t.rdb$relation_name = old.table_name
                            and t.rdb$trigger_name = :trigger_name
                            and coalesce(t.rdb$trigger_inactive, 0) = 0)
        ) then
        begin
            -- disable tracking trigger
            execute statement 'alter trigger ' || trim(trigger_name) || ' inactive;';
            -- adds comment about diabling reasons for tracking trigger
            execute statement 'comment on trigger ' || trim(trigger_name) || ' is '''
                                || 'disabled (' || current_timestamp || ')'
                                || ' because of deleting record from `dbmon_tracked_field`' || ascii_char(10)
                                || 'table_name=' || coalesce('''''' || old.table_name || '''''', 'null') || ascii_char(10)
                                || 'field_name=' || coalesce('''''' || old.field_name || '''''', 'null') || ascii_char(10)
                                || 'enabled=' || coalesce(old.enabled, 'null') || ascii_char(10)
                                || 'extra_cond=' || coalesce('''''' || old.extra_cond || '''''', 'null') || ascii_char(10)
                                || 'exclude_roles=' || coalesce('''''' || old.exclude_roles || '''''', 'null') || ascii_char(10)
                                || 'log_call_stack=' || coalesce(old.log_call_stack, 'null') || ascii_char(10)
                                || 'errors=' || coalesce('''''' || old.errors || '''''', 'null') || ascii_char(10)
                                || ''';';
        end
    end
end^

set term ; ^

comment on trigger dbmon_tracked_field_ad is 'Processing removing tracked fields.
See https://github.com/atronah/firebird_utils/tree/master/dbmon for details.';