set term ^ ;
create or alter trigger dbmon_block_stucture_change_bui
    active
    before update or insert
    on dbmon_block_stucture_changes
as
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master/dbmon

    new.object_type = upper(trim(new.object_type));
    new.object_name = upper(trim(new.object_name));

    when any do
    begin
    end
end^

set term ; ^

comment on trigger dbmon_data_changelog_bui is 'Trigger to calculate default values for some columns if they have not been passed.
See https://github.com/atronah/firebird_utils/tree/master/dbmon for details.';