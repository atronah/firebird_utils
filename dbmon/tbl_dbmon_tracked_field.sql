create table dbmon_tracked_field(
    table_name varchar(1024)
    , field_name varchar(1024)
    , enabled smallint
    , update_track_triggers smallint
    , log_call_stack smallint
    , constraint pk_dbmon_tracked_field primary key (table_name, field_name)
);

comment on table dbmon_tracked_field is 'Fields of tables to track changes data in it.
After changes you should re-create tracking triggers for table using
`execute procedure dbmon_recreate_trigger[(:table_name)]`
(or pass value `1` to field update_track_triggers)';

comment on column dbmon_tracked_field.table_name is 'Name of table to track data changing in specified field';
comment on column dbmon_tracked_field.field_name is 'Name of column of table to track data changing in it';
comment on column dbmon_tracked_field.enabled is 'Enables tracking if is not `null`/`0`';
comment on column dbmon_tracked_field.update_track_triggers is 'If passed 1, triggers for table will be recreated by dbmon_recreate_trigger';
comment on column dbmon_tracked_field.log_call_stack is 'If passed 1, call stack will be added to logged data of changes';