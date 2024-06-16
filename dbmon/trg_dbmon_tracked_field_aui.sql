set term ^ ;
create or alter trigger dbmon_tracked_field_aui
    active
    after update or insert
    on dbmon_tracked_field
as
begin
    if (new.update_track_triggers = 1) then
    begin
        execute procedure dbmon_create_triggers(new.table_name, 1);

        update dbmon_tracked_field
            set update_track_triggers = 0
            where table_name = new.table_name
                and field_name = new.field_name;
    end
end^

set term ; ^
