set term ^ ;
create or alter trigger conmgr_connection_check
    active
    on connect
as
declare is_blocked smallint;

declare info type of column conmgr_log.info;
declare detailed_info type of column conmgr_log.detailed_info;

declare conn_id type of column conmgr_log.attachment_id;
declare conn_timestamp type of column conmgr_log.attachment_timestamp;

declare conn_db_user type of column conmgr_rule.db_user;
declare conn_role type of column conmgr_rule.role;
declare conn_remote_process type of column conmgr_rule.remote_process;
declare conn_remote_host type of column conmgr_rule.remote_host;
declare conn_remote_os_user type of column conmgr_rule.remote_os_user;

declare rule_id type of column conmgr_rule.rule_id;
declare rule_type type of column conmgr_rule.rule_type;

declare start_date type of column conmgr_rule.start_date;
declare end_date type of column conmgr_rule.end_date;
declare start_time type of column conmgr_rule.start_time;
declare end_time type of column conmgr_rule.end_time;

declare is_date_match smallint;
declare is_time_match smallint;

declare rule_db_user type of column conmgr_rule.db_user;
declare rule_role type of column conmgr_rule.role;
declare rule_remote_process type of column conmgr_rule.remote_process;
declare rule_remote_host type of column conmgr_rule.remote_host;
declare rule_remote_os_user type of column conmgr_rule.remote_os_user;
declare rule_message type of column conmgr_rule.message;
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master/conmgr

    is_blocked = 0;

    conn_db_user = current_user;
    conn_role = current_role;
    conn_remote_process = rdb$get_context('SYSTEM', 'CLIENT_PROCESS');

     select
            mon$attachment_id, mon$timestamp
            , mon$remote_host, mon$remote_os_user
        from mon$attachments as a
        where a.mon$attachment_id = current_connection
        into conn_id, conn_timestamp, conn_remote_host, conn_remote_os_user;

    for  select
            r.rule_id
            , upper(trim(r.rule_type)) as rule_type
            , r.message

            , r.start_date, r.end_date
            , r.start_time, r.end_time

            , r.db_user, r.role
            , r.remote_process, r.remote_host, r.remote_os_user

        from conmgr_rule as r
        where r.enabled = 1
            and :conn_db_user like coalesce(r.db_user, :conn_db_user)
            and (:conn_role is null or :conn_role like coalesce(r.role, :conn_role))
            and (:conn_remote_process is null or :conn_remote_process like coalesce(r.remote_process, :conn_remote_process))
            and (:conn_remote_host is null or :conn_remote_host like coalesce(r.remote_host, :conn_remote_host))
            and (:conn_remote_os_user is null or :conn_remote_os_user like coalesce(r.remote_os_user, :conn_remote_os_user))
        into rule_id
            , rule_type
            , rule_message
            , start_date, end_date
            , start_time, end_time
            , rule_db_user, rule_role
            , rule_remote_process, rule_remote_host, rule_remote_os_user
    do
    begin
        detailed_info = left('Found enabled ' || coalesce(rule_type, 'null') || ' rule for: ' || ascii_char(10)
                                || trim(coalesce('DB user: ' || rule_db_user || ascii_char(10), ''))
                                || trim(coalesce('Role:' || rule_role || ascii_char(10), ''))
                                || trim(coalesce('Remote process:' || rule_remote_process || ascii_char(10), ''))
                                || trim(coalesce('Remote host:' || rule_remote_host || ascii_char(10), ''))
                                || trim(coalesce('Remote OS user:' || rule_remote_os_user || ascii_char(10), ''))
                                || trim(coalesce('Date interval: '
                                                || nullif(trim(coalesce('from ' || start_date, '')
                                                                || ' '
                                                                || coalesce('to ' || end_date, ''))
                                                            , '')
                                                , ''))
                                || trim(coalesce('Time interval: '
                                                || nullif(trim(coalesce('from ' || start_time, '')
                                                                || ' '
                                                                || coalesce('to ' || end_time, ''))
                                                            , '')
                                                , ''))
                            , 4096);
        if (start_date is not null or end_date is not null) then
        begin
            is_date_match = iif(cast(conn_timestamp as date)
                                    between coalesce(start_date, cast(conn_timestamp as date))
                                        and coalesce(end_date, cast(conn_timestamp as date))
                                , 1, 0);
        end
        else is_date_match = 1;

        if (start_time is not null or end_time is not null) then
        begin
            is_time_match = iif(cast(conn_timestamp as time)
                                between coalesce(start_time, cast(conn_timestamp as time))
                                        and coalesce(end_time, cast(conn_timestamp as time))
                                , 1, 0);
        end
        else is_time_match = 1;

        if ((rule_type = 'ALLOW'
                -- blocks connection if EITHER its date NOT mathes rule dates NOR its time NOT mathes rule times
                -- (missed dates/times are equal matched date/time).
                -- Examples:
                -- for 01.01.2000-null (dates) and null-null (times):
                --     blocks all connection before 01.01.2000 at any time;
                -- for null-null (dates) and 01:00-03:00 (times):
                --     blocks all connections not between 01:00 and 03:00 any day;
                -- for null-01.03.2020 (dates) and null-12:00 (times):
                --     blocks all connections after 01.03.2020 at any time and all connection after 12:00 any day;
                and (is_date_match = 0 or is_time_match = 0)
            )
            or (rule_type = 'DENY'
                -- blocks connection if both its date matches rule dates and its time matches rule times
                -- (missed dates/times are equal matched date/time).
                and (is_date_match = 1 and is_time_match = 1)
            )
        ) then is_blocked = 1;

        if (is_blocked > 0)
            then break;
    end

    if (is_blocked > 0) then
    begin
        in autonomous transaction do
        begin
            insert into conmgr_log
                            (info, detailed_info
                            , rule_id
                            , db_user, role, remote_process, remote_host, remote_os_user
                            , attachment_id, attachment_timestamp)
                    values ('Connection blocked', :detailed_info
                            , :rule_id
                            , :conn_db_user, :conn_role
                            , :conn_remote_process, :conn_remote_host, :conn_remote_os_user
                            , :conn_id, :conn_timestamp);

        end

        exception conmgr_connection_blocked trim(coalesce(rule_message, '') || ' (rule_id=' || coalesce(rule_id, 'null') || ')');
    end
end^

set term ; ^

comment on trigger conmgr_connection_check is 'Trigger to check whether the connection is allowed or not
(based on the configured rules from table conmgr_rule).
See https://github.com/atronah/firebird_utils/tree/master/conmgr for details.';