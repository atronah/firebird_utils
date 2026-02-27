set term ^ ;
create or alter trigger dbmon_structure_changelog_bui
    active
    before update or insert
    on dbmon_structure_changelog
as
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

    new.session_id = coalesce(new.session_id, old.session_id, current_connection);
    new.transaction_id = coalesce(new.transaction_id, old.transaction_id, current_transaction);
    new.isolation_level = coalesce(new.isolation_level, old.isolation_level, rdb$get_context('SYSTEM', 'ISOLATION_LEVEL'));
    new.client_pid = coalesce(new.client_pid, old.client_pid, rdb$get_context('SYSTEM', 'CLIENT_PID'));
    new.engine_version = coalesce(new.engine_version, old.engine_version, rdb$get_context('SYSTEM', 'ENGINE_VERSION'));

    select
            coalesce(new.server_pid, a.server_pid)
            , coalesce(new.auth_method, a.auth_method)
            , coalesce(new.client_version, a.client_version)
            , coalesce(new.client_os_user, a.client_os_user)
        from dbmon_attachment_info as a
        into new.server_pid, new.auth_method, new.client_version, new.client_os_user;

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