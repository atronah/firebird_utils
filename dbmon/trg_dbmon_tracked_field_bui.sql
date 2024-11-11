set term ^ ;
create or alter trigger dbmon_tracked_field_bui
    active
    before update or insert
    on dbmon_tracked_field
as
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master/dbmon

    new.table_name = upper(trim(new.table_name));
    new.field_name = upper(trim(new.field_name));
    new.enabled = coalesce(new.enabled, 0);
    new.update_track_triggers = coalesce(new.update_track_triggers, 0);
    new.log_call_stack = coalesce(new.log_call_stack, 0);
end^

set term ; ^

comment on trigger dbmon_tracked_field_bui is 'Trigger to calculate default values for some columns if they have not been passed.
See https://github.com/atronah/firebird_utils/tree/master/dbmon for details.';