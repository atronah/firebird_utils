create table dbmon_data_changelog(
    change_id bigint
    , db_name varchar(255)

    , table_name varchar(1024)
    , primary_key_1 varchar(255)
    , primary_key_2 varchar(255)
    , primary_key_3 varchar(255)
    , primary_key_fields varchar(1024)

    , changed_field_name varchar(32)
    , changed timestamp
    , change_type varchar(32)
    , change_comment varchar(4096)
    , old_value varchar(4096)
    , new_value varchar(4096)

    , call_stack varchar(4096)

    , client_host varchar(1024)
    , client_os_user varchar(1024)
    , client_process varchar(1024)
    , client_user varchar(255)
    , client_role varchar(255)
    , client_protocol varchar(16)
    , client_version varchar(255)

    , session_id bigint
    , transaction_id bigint
    , isolation_level varchar(64)
    , client_pid bigint
    , server_pid bigint
    , auth_method varchar(255)
    , engine_version varchar(32)

    , context_variables varchar(4096)

    , constraint pk_dbmon_data_changelog primary key (change_id)
);


comment on table dbmon_data_changelog is 'Table to store history of changes of data in monitored tables (specified in dbmon_tracked_field).
See https://github.com/atronah/firebird_utils/tree/master/dbmon for details.';
comment on column dbmon_data_changelog.change_id is 'Identifier of changes (generating automatically by dbmon_data_changelog_seq in dbmon_date_changelog_bui)';

comment on column dbmon_data_changelog.db_name is 'Name of database';
comment on column dbmon_data_changelog.table_name is 'Name of table where changes has been detected';
comment on column dbmon_data_changelog.primary_key_1 is 'Value of first part of primary key of changed record';
comment on column dbmon_data_changelog.primary_key_2 is 'Value of second part of primary key of changed record';
comment on column dbmon_data_changelog.primary_key_3 is 'Value of third part of primary key of changed record';
comment on column dbmon_data_changelog.primary_key_fields is 'List of fields, used as primary key';

comment on column dbmon_data_changelog.changed_field_name is 'Name of column where changes has been detected';
comment on column dbmon_data_changelog.changed is 'Date and time when changes was made';
comment on column dbmon_data_changelog.change_type is 'Type of statement, which is initiated changes: `INSERT`, `UPDATE` or `DELETE`';
comment on column dbmon_data_changelog.change_comment is 'Comment for change from author (to history reason)';
comment on column dbmon_data_changelog.old_value is 'First 4096 symbols of old value (before changes)';
comment on column dbmon_data_changelog.new_value is 'First 4096 symbols of new value (before changes)';

comment on column dbmon_data_changelog.call_stack is 'Call stack from MON$CALL_STACK for all statements of current session (attachment)';

comment on column dbmon_data_changelog.client_host is 'The wire protocol host name of remote client. Value is returned for all supported protocols';
comment on column dbmon_data_changelog.client_os_user is 'Name of user in client operation system';
comment on column dbmon_data_changelog.client_process is 'Process name of remote client application.';
comment on column dbmon_data_changelog.client_user is 'Name of the connected user who made changes';
comment on column dbmon_data_changelog.client_role is 'Role of the connected user who made changes';
comment on column dbmon_data_changelog.client_protocol is 'he protocol used for the connection: `TCPv4`, `TCPv6`, `WNET`, `XNET` or NULL.';
comment on column dbmon_data_changelog.client_version is 'Client library version';

comment on column dbmon_data_changelog.session_id is 'Connection identifier (mon$attachment_id)';
comment on column dbmon_data_changelog.transaction_id is 'Transaction identifier (mon$transaction_id)';
comment on column dbmon_data_changelog.isolation_level is 'The isolation level of the current transaction: `READ COMMITTED`, `SNAPSHOT` or `CONSISTENCY`';
comment on column dbmon_data_changelog.client_pid is 'Process ID of remote client application';
comment on column dbmon_data_changelog.server_pid is 'Server process identifier';
comment on column dbmon_data_changelog.auth_method is 'Name of authentication plugin used to connect';
comment on column dbmon_data_changelog.engine_version is 'The Firebird engine (server) version';

comment on column dbmon_data_changelog.context_variables is 'Values of context variables from MON$CONTEXT_VARIABLES for current transaction and current session';

create sequence dbmon_data_changelog_seq;

create desc index idx_dbmon_dat_changelog_changed on dbmon_data_changelog (changed);
create asc index idx_dbmon_dat_changelog_tbl_key on dbmon_data_changelog (table_name, primary_key_1, primary_key_2, primary_key_3);
