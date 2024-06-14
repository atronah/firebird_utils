set term ^ ;
create or alter trigger dbmon_structure_changelog_bui
    active
    before update or insert
    on dbmon_structure_changelog
as
declare context_variable_name type of column mon$context_variables.mon$variable_name;
declare context_variable_value type of column mon$context_variables.mon$variable_value;
begin
    new.change_id = coalesce(new.change_id, old.change_id, next value for dbmon_structure_changelog_seq);

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

    if (nullif(trim(new.client_os_user), '') is null
            or nullif(trim(new.client_version), '') is null
            or nullif(trim(new.server_pid), '') is null
            or nullif(trim(new.auth_method), '') is null
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
    end

    if (new.context_variables is null) then
    begin
        new.context_variables = '';

        for select distinct
              mon$variable_name, mon$variable_value
          from mon$context_variables
          where mon$attachment_id = current_connection
              or mon$transaction_id = rdb$get_context('SYSTEM', 'TRANSACTION_ID')
          order by 1
          into context_variable_name, context_variable_value
        do
        begin
           new.context_variables = left(new.context_variables
                                        || coalesce(context_variable_name, 'null')
                                        || '='
                                        || coalesce(context_variable_value, 'null')
                                        || ascii_char(13) || ascii_char(10)
                                    , 4096);
        end
    end

    when any do
    begin
    end
end^

set term ; ^

comment on trigger dbmon_structure_changelog_bui is 'Trigger to calculate default values for some columns if they have not been passed.
See https://github.com/atronah/firebird_utils/tree/master/dbmon for details.';