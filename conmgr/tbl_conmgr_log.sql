create sequence conmgr_log_seq;

create table conmgr_log (
    log_id bigint

    , logged timestamp

    , info varchar(1024)
    , detailed_info varchar(4096)

    , rule_id varchar(16)

    , db_user varchar(255)
    , role varchar(255)
    , remote_process varchar(1024)
    , remote_host varchar(1024)
    , remote_os_user varchar(1024)

    , attachment_id bigint
    , attachment_timestamp timestamp

    , constraint pk_conmgr_log primary key (log_id)
);

comment on table conmgr_log is 'Table to store logs.
See https://github.com/atronah/firebird_utils/tree/master/conmgr for details.';

comment on column conmgr_log.log_id is 'Identifier of log (generating automatically by conmgr_log_seq in conmgr_log_bui)';
comment on column conmgr_log.logged is 'Date and time when log was recorded into table';
comment on column conmgr_log.rule_id is 'Identifier of related rule (`conmgr_rule.rule_id`)';