create table dbmon_block_stucture_changes(
    object_type varchar(32)
    , object_name varchar(1024)
    , enabled smallint
    , comment varchar(1024)

    , constraint pk_dbmon_block_stucture_changes primary key (object_type, object_name)
);


comment on table dbmon_block_stucture_changes is 'Table to block/unblock changes in structure of database for specified database objects (tables, procedures, triggers, domains, etc.)';
comment on column dbmon_block_stucture_changes.object_type is 'Type of changing database object';
comment on column dbmon_block_stucture_changes.object_name is 'Name of changing database object';
comment on column dbmon_block_stucture_changes.enabled is 'Enables block if is not `null`/`0`';
comment on column dbmon_block_stucture_changes.comment is 'Some comments about reason of blocking changes';