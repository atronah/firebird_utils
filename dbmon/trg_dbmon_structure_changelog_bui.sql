set term ^ ;
create or alter trigger dbmon_structure_changelog_bui
    active
    before update or insert
    on dbmon_structure_changelog
as
declare log_attachment_client_os_user smallint;
declare log_attachment_client_version smallint;
declare log_attachment_server_pid smallint;
declare log_attachment_auth_method smallint;
declare log_context_variables type of column dbmon_settings.val;
declare context_variable_name type of column mon$context_variables.mon$variable_name;
declare context_variable_value type of column mon$context_variables.mon$variable_value;
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master/dbmon

    new.change_id = coalesce(new.change_id, old.change_id, next value for dbmon_structure_changelog_seq);

    new.old_object_name = coalesce(new.old_object_name, old.old_object_name); -- prevent erasing old_object_name

    new.db_name = coalesce(nullif(new.db_name, ''), nullif(old.db_name, ''), rdb$get_context('SYSTEM', 'DB_NAME'));

    new.changed = coalesce(new.changed, old.changed, current_timestamp);
    new.checked = coalesce(new.checked, old.checked, current_timestamp);

    new.object_type = upper(trim(new.object_type));
    new.object_name = upper(trim(new.object_name));
    new.change_type = upper(coalesce(new.change_type, old.change_type, 'unknown'));

    new.client_host = coalesce(new.client_host, old.client_host, rdb$get_context('SYSTEM', 'CLIENT_HOST'));
    new.client_process = coalesce(new.client_process, old.client_process, rdb$get_context('SYSTEM', 'CLIENT_PROCESS'));
    new.client_user = coalesce(new.client_user, old.client_user, current_user);
    new.client_role = coalesce(new.client_role, old.client_role, current_role);
    new.client_protocol = coalesce(new.client_protocol, old.client_protocol, rdb$get_context('SYSTEM', 'NETWORK_PROTOCOL'));
    new.client_version = coalesce(new.client_protocol, old.client_protocol, rdb$get_context('SYSTEM', 'NETWORK_PROTOCOL'));
    new.client_os_user = coalesce(new.client_os_user, old.client_os_user, rdb$get_context('USER_SESSION', 'DBMON_CLIENT_OS_USER'));
    new.server_pid = coalesce(new.server_pid, old.server_pid, rdb$get_context('USER_SESSION', 'DBMON_SERVER_PID'));
    new.auth_method = coalesce(new.auth_method, old.auth_method, rdb$get_context('USER_SESSION', 'DBMON_AUTH_METHOD'));

    new.session_id = coalesce(new.session_id, old.session_id, current_connection);
    new.transaction_id = coalesce(new.transaction_id, old.transaction_id, current_transaction);
    new.isolation_level = coalesce(new.isolation_level, old.isolation_level, rdb$get_context('SYSTEM', 'ISOLATION_LEVEL'));
    new.client_pid = coalesce(new.client_pid, old.client_pid, rdb$get_context('SYSTEM', 'CLIENT_PID'));
    new.engine_version = coalesce(new.engine_version, old.engine_version, rdb$get_context('SYSTEM', 'ENGINE_VERSION'));

    log_attachment_client_os_user = (select iif(val similar to '0|1', val, 0) from dbmon_settings where key = 'log_attachment_client_os_user');
    log_attachment_client_version = (select iif(val similar to '0|1', val, 0) from dbmon_settings where key = 'log_attachment_client_version');
    log_attachment_server_pid = (select iif(val similar to '0|1', val, 0) from dbmon_settings where key = 'log_attachment_server_pid');
    log_attachment_auth_method = (select iif(val similar to '0|1', val, 0) from dbmon_settings where key = 'log_attachment_auth_method');
    if (nullif(trim(new.client_os_user), '') is null and log_attachment_client_os_user > 0
            or nullif(trim(new.client_version), '') is null and log_attachment_client_version > 0
            or nullif(trim(new.server_pid), '') is null and log_attachment_server_pid > 0
            or nullif(trim(new.auth_method), '') is null and log_attachment_auth_method > 0
        ) then
    begin
        select
                coalesce(nullif(trim(new.client_os_user), ''), nullif(trim(a.mon$remote_os_user), ''))
                , coalesce(nullif(trim(new.client_version), ''), nullif(trim(a.mon$client_version), ''))
                , coalesce(nullif(trim(new.server_pid), ''), nullif(trim(a.mon$server_pid), ''))
                , coalesce(nullif(trim(new.auth_method), ''), nullif(trim(a.mon$auth_method), ''))
            from mon$attachments as a
            where a.mon$attachment_id = current_connection
            into new.client_os_user, new.client_version, new.server_pid, new.auth_method;

        if (new.client_os_user is not null)
            then rdb$set_context('USER_SESSION', 'DBMON_CLIENT_OS_USER', new.client_os_user);
        if (new.client_os_user is not null)
            then rdb$set_context('USER_SESSION', 'DBMON_SERVER_PID', new.server_pid);
        if (new.client_os_user is not null)
            then rdb$set_context('USER_SESSION', 'DBMON_AUTH_METHOD', new.auth_method);
    end


    log_context_variables = (select val from dbmon_settings where key = 'log_context_variables');
    if (new.context_variables is null and log_context_variables > '') then
    begin
        new.context_variables = '';
        for select part
            from aux_split_text(:log_context_variables, ';')
            where part containing '.'
            into context_variable_name
        do
        begin
            context_variable_value = rdb$get_context(trim(substring(context_variable_name
                                                                    from 1
                                                                    for position('.' in context_variable_name) - 1))
                                                    , trim(substring(context_variable_name
                                                                    from position('.' in context_variable_name) + 1))
                                                    );

            new.context_variables = left(new.context_variables
                                        || coalesce(context_variable_name, 'null')
                                        || '='
                                        || coalesce(context_variable_value, 'null')
                                        || ascii_char(13) || ascii_char(10)
                                    , 4096);

            when any do
            begin
                new.context_variables = left(new.context_variables
                                                || 'Exception when getting value of variable "'
                                                || coalesce(context_variable_name, 'null')
                                                || '"'
                                                || ascii_char(13) || ascii_char(10)
                                            , 4096);
            end
        end
    end

    when any do
    begin
    end
end^

set term ; ^

comment on trigger dbmon_structure_changelog_bui is 'Trigger to calculate default values for some columns if they have not been passed.
See https://github.com/atronah/firebird_utils/tree/master/dbmon for details.';