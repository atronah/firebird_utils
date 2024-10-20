drop trigger dbmon_before_any_ddl_statement;


drop procedure dbmon_check_for_changes;
drop procedure dbmon_recreate_trigger;

drop table dbmon_changes_history;
drop table dbmon_structure_changelog;
drop table dbmon_data_changelog;
drop table dbmon_tracked_field;

drop sequence dbmon_data_changelog_seq;
drop sequence dbmon_structure_changelog_seq;
