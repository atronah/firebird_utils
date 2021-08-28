create table dbmon_changes_history(
    db varchar(255)
    , obj_type varchar(16) -- table, procedure, trigger, view
    , obj_name varchar(31)
    , changed timestamp
    , checked timestamp
    , create_statement blob sub_type text
    , constraint pk_mds_dbmon_entity_history primary key (db, obj_type, obj_name, changed)
);

create desc index idx_dbmon_changes_history on dbmon_changes_history (checked);
create asc index idx_dbmon_changes_history_name on dbmon_changes_history (obj_name);