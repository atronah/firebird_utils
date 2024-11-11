set term ^ ;
create or alter trigger dbmon_tracked_field_aui
    active
    after update or insert
    on dbmon_tracked_field
as
declare count_of_created_triggers bigint;
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master/dbmon

    if (new.update_track_triggers = 1) then
    begin
        count_of_created_triggers = (select count_of_created_triggers
                                        from dbmon_create_triggers(new.table_name, 1));

        update dbmon_tracked_field
            set update_track_triggers = 0
            where table_name = new.table_name
                and field_name = new.field_name;
    end
end^

set term ; ^

comment on trigger dbmon_tracked_field_aui is 'Trigger to process `update_track_triggers` flag in dbmon_tracked_field.
See https://github.com/atronah/firebird_utils/tree/master/dbmon for details.';