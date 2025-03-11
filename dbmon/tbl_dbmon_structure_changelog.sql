create table dbmon_structure_changelog(
    change_id bigint
    , db_name varchar(255)
    , object_type varchar(32) -- table, procedure, trigger, view
    , object_name varchar(1024)

    , checked timestamp
    , changed timestamp

    , change_type varchar(32)
    , change_comment varchar(4096)

    , sql_text blob sub_type text

    , old_object_name varchar(1024)
    , new_object_name varchar(1024)

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

    , prev_unified_create_statement blob sub_type text

    , constraint pk_dbmon_structure_changelog primary key (change_id)
);


comment on table dbmon_structure_changelog is 'Table to store history of changes in database structure.
See https://github.com/atronah/firebird_utils/tree/master/dbmon for details.';
comment on column dbmon_structure_changelog.change_id is 'Identifier of changes (generating automatically by dbmon_structure_changelog_seq in dbmon_structure_changelog_bui)';
comment on column dbmon_structure_changelog.db_name is 'Name of database';
comment on column dbmon_structure_changelog.object_type is 'Type of changed database object';
comment on column dbmon_structure_changelog.object_name is 'Name of changed database object';

comment on column dbmon_structure_changelog.checked is 'Date and time when changes was checked (for peridicaly checking)';
comment on column dbmon_structure_changelog.changed is 'Date and time when changes was made';

comment on column dbmon_structure_changelog.change_type is 'Type of changes (see `EVENT_TYPE` of `DDL_TRIGGER` namespace).
For checks using aux_get_create_statement should be `AUX_GET_CREATE_STATEMENT`';
comment on column dbmon_structure_changelog.change_comment is 'Comment for change from author (to history reason)';

comment on column dbmon_structure_changelog.sql_text is 'Sql text which makes changes (see `SQL_TEXT` of `DDL_TRIGGER` namespace)';

comment on column dbmon_structure_changelog.old_object_name is 'Name of changed database object before changes (see `OLD_OBJECT_NAME` of `DDL_TRIGGER` namespace)';
comment on column dbmon_structure_changelog.new_object_name is 'Name of changed database object after changes (see `OLD_OBJECT_NAME` of `DDL_TRIGGER` namespace)';

comment on column dbmon_structure_changelog.client_host is 'The wire protocol host name of remote client. Value is returned for all supported protocols';
comment on column dbmon_structure_changelog.client_os_user is 'Name of user in client operation system';
comment on column dbmon_structure_changelog.client_process is 'Process name of remote client application.';
comment on column dbmon_structure_changelog.client_user is 'Name of the connected user who made changes';
comment on column dbmon_structure_changelog.client_role is 'Role of the connected user who made changes';
comment on column dbmon_structure_changelog.client_protocol is 'he protocol used for the connection: `TCPv4`, `TCPv6`, `WNET`, `XNET` or NULL.';
comment on column dbmon_structure_changelog.client_version is 'Client library version';

comment on column dbmon_structure_changelog.session_id is 'Connection identifier (mon$attachment_id)';
comment on column dbmon_structure_changelog.transaction_id is 'Transaction identifier (mon$transaction_id)';
comment on column dbmon_structure_changelog.isolation_level is 'The isolation level of the current transaction: `READ COMMITTED`, `SNAPSHOT` or `CONSISTENCY`';
comment on column dbmon_structure_changelog.client_pid is 'Process ID of remote client application';
comment on column dbmon_structure_changelog.server_pid is 'Server process identifier';
comment on column dbmon_structure_changelog.auth_method is 'Name of authentication plugin used to connect';
comment on column dbmon_structure_changelog.engine_version is 'The Firebird engine (server) version';

comment on column dbmon_structure_changelog.context_variables is 'Values of context variables from MON$CONTEXT_VARIABLES for current transaction and current session';

comment on column dbmon_structure_changelog.prev_unified_create_statement is 'Create statement for previous version of database object (before update) computed by procedure `aux_get_create_statement`';

create sequence dbmon_structure_changelog_seq;

create desc index idx_dbmon_str_changelog_checked on dbmon_structure_changelog (checked);
create desc index idx_dbmon_str_changelog_changed on dbmon_structure_changelog (changed);
create asc index idx_dbmon_str_changelog_dtnctc on dbmon_structure_changelog (object_name, object_type, db_name, change_type, changed);
