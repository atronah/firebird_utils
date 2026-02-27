alter table dbmon_structure_changelog add prev_unified_create_statement blob sub_type text;

alter table dbmon_tracked_field add errors varchar(1024);
alter table dbmon_tracked_field add attachment_info_logging_mode smallint;
alter table dbmon_tracked_field add attachment_info_user_query varchar(1024);
