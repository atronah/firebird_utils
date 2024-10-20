create table dbmon_settings(
    key varchar(64)
    , val varchar(1024)
    , description varchar(1024)
    , constraint dbmon_settings primary key (key)
);


comment on table dbmon_settings is 'Table to store dbmon settings.
See https://github.com/atronah/firebird_utils/tree/master/dbmon for details.';
comment on column dbmon_settings.key is 'Key (name) of setting';
comment on column dbmon_settings.val is 'Value of setting';
comment on column dbmon_settings.description is 'Description of setting';