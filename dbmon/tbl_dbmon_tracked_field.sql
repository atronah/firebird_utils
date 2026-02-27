create table dbmon_tracked_field(
    table_name varchar(1024)
    , field_name varchar(1024)
    , enabled smallint
    , extra_cond varchar(1024)
    , exclude_roles varchar(1024)
    , update_track_triggers smallint
    , log_call_stack smallint
    , attachment_info_logging_mode smallint
    , attachment_info_user_query varchar(1024)
    , errors varchar(1024)
    , constraint pk_dbmon_tracked_field primary key (table_name, field_name)
);

comment on table dbmon_tracked_field is 'Fields of tables to track changes data in it.
After changes you should re-create tracking triggers for table using
`execute procedure dbmon_create_triggers[(:table_name)]`
(or pass value `1` to field update_track_triggers).
See https://github.com/atronah/firebird_utils/tree/master/dbmon for details.';

comment on column dbmon_tracked_field.table_name is 'Name of table to track data changing in specified field';
comment on column dbmon_tracked_field.field_name is 'Name of column of table to track data changing in it.
Special values:
- `*` all fields changes will be tracked separatelly
- `?` changes of any field will be tracked as one log record with `?` in `changed_field_name`';
comment on column dbmon_tracked_field.enabled is 'Enables tracking if is not `null`/`0`';
comment on column dbmon_tracked_field.extra_cond is 'Extra cond with using fields of `new` and `old` record, to reduce record of tracking';
comment on column dbmon_tracked_field.exclude_roles is 'Database roles separated by comma for whom tracking is disabled';
comment on column dbmon_tracked_field.update_track_triggers is 'If passed 1, triggers for table will be recreated by dbmon_create_triggers';
comment on column dbmon_tracked_field.log_call_stack is 'If passed 1, call stack will be added to logged data of changes';
comment on column dbmon_tracked_field.errors is 'Description of the error that occurred while processing changes';
