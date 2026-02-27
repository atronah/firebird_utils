create sequence conmgr_rule_seq;

create table conmgr_rule (
    rule_id bigint

    , rule_type varchar(16)
    , enabled smallint

    , comment varchar(1024)

    , start_date date
    , end_date date

    , start_time time
    , end_time time

    , db_user varchar(255)
    , role varchar(255)
    , remote_process varchar(1024)
    , remote_host varchar(1024)
    , remote_os_user varchar(1024)

    , message varchar(512)

    , constraint pk_conmgr_rule primary key (rule_id)
);


comment on table conmgr_rule is 'Table to store blocking rules for connections.
See https://github.com/atronah/firebird_utils/tree/master/conmgr for details.

Examples:

1. Rule to block all connections with role `GOD` until 01.01.2000
(allow connections with role `GOD` only after 01.01.2000):

`rule_type = ''ALLOW''`
`enabled=1`
`start_date=''01.01.2000''`
`role=''GOD''`

that rule will be processed for all connections with role `GOD`
and will block those of them that have, that started before 01.01.2000.

2. Rule to block all connections from user `TEST` for times between 10:00 and 18:00:

`rule_type = ''DENY''`
`enabled=1`
`start_time=''10:00''`
`end_time=''18:00''`
`db_user=''TEST''`

3. Rule to block all connections from process `my.exe` after 18:00 every day after 01.02.2023

`rule_type = ''DENY''`
`enabled=1`
`start_date=''01.02.2023''`
`start_time=''18:00''`
`remote_process=''%/my.exe''`
';

comment on column conmgr_rule.rule_id is 'Identifier of rule (generating automatically by conmgr_rule_seq in conmgr_rule_bui)';
comment on column conmgr_rule.rule_type is 'Type of rule. Allowed values:
- `ALLOW` - blocks all connections that match the rule (by `db_user`, `role`, `remote_process`, `remote_host`, `remote_os_user`),
but that tries connect not in specified dates and/or times
- `DENY` - blocks all connections that match the rule
(either when tries connect in the specified date/time periods or when date/times not specified at all)
';
comment on column conmgr_rule.enabled is 'Only rules with enabled=1 processed when connectios is checking.';
comment on column conmgr_rule.comment is 'Comment for rule';
comment on column conmgr_rule.start_date is 'Start date of period when connection is allowed/denied (depending on the `rule_type`).
Considered equal to the connection date if not specified, but `end_date` is not null.';
comment on column conmgr_rule.end_date is 'End date of period when connection is allowed/denied (depending on the `rule_type`).
Considered equal to the connection date if not specified, but `start_date` is not null.';
comment on column conmgr_rule.start_time is 'Start time of period when connection is allowed/denied (depending on the `rule_type`).
Considered equal to the connection time if not specified, but `end_time` is not null.';
comment on column conmgr_rule.end_time is 'End time of period when connection is allowed/denied (depending on the `rule_type`).
Considered equal to the connection time if not specified, but `start_time` is not null.';
comment on column conmgr_rule.db_user is 'If specified, the rule is processed only for connections, whose database user (`current_user`) matches (by `like`) value of that field';
comment on column conmgr_rule.role is 'If specified, the rule is processed only for connections, whose database role (`current_role`) matches (by `like`) value of that field';
comment on column conmgr_rule.remote_process is 'If specified, the rule is processed only for connections, whose remote process (`mon$attachments.mon$remote_process`) matches (by `like`) value of that field';
comment on column conmgr_rule.remote_host is 'If specified, the rule is processed only for connections, whose remote host (`mon$attachments.mon$remote_host`) matches (by `like`) value of that field';
comment on column conmgr_rule.remote_os_user is 'If specified, the rule is processed only for connections, whose remote os user (`mon$attachments.mon$remote_os_user`) matches (by `like`) value of that field';

comment on column conmgr_rule.message is 'Messagem that shows when exeption is raised';