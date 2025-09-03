set term ^ ;
create or alter trigger dbmon_data_changelog_bui
    active
    before update or insert
    on dbmon_data_changelog
as
declare field_name type of column rdb$index_segments.rdb$field_name;
declare call_stack_call_id type of column mon$call_stack.mon$call_id;
declare call_stack_caller_id type of column mon$call_stack.mon$caller_id;
declare call_stack_object_name type of column mon$call_stack.mon$object_name;
declare call_stack_object_type type of column mon$call_stack.mon$object_type;
declare call_stack_timestamp type of column mon$call_stack.mon$timestamp;
declare call_stack_source_line type of column mon$call_stack.mon$source_line;
declare call_stack_source_column type of column mon$call_stack.mon$source_column;
declare context_variable_name type of column mon$context_variables.mon$variable_name;
declare context_variable_value type of column mon$context_variables.mon$variable_value;

declare log_attachement_client_os_user smallint;
declare log_attachement_client_version smallint;
declare log_attachement_server_pid smallint;
declare log_attachement_auth_method smallint;
declare log_call_stack smallint;
declare log_context_variables type of column dbmon_settings.val;
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master/dbmon

    new.change_id = coalesce(new.change_id, old.change_id, next value for dbmon_data_changelog_seq);
    new.old_value = coalesce(new.old_value, old.old_value); -- prevent erasing old value

    new.db_name = coalesce(nullif(new.db_name, ''), nullif(old.db_name, ''), rdb$get_context('SYSTEM', 'DB_NAME'));

    new.changed = coalesce(new.changed, old.changed, current_timestamp);

    new.table_name = upper(trim(new.table_name));
    new.changed_field_name = upper(trim(new.changed_field_name));
    new.change_type = upper(coalesce(new.change_type, old.change_type, 'unknown'));
    new.primary_key_fields = coalesce(new.primary_key_fields, old.primary_key_fields);

    new.client_host = coalesce(new.client_host, old.client_host, rdb$get_context('SYSTEM', 'CLIENT_HOST'));
    new.client_process = coalesce(new.client_process, old.client_process, rdb$get_context('SYSTEM', 'CLIENT_PROCESS'));
    new.client_user = coalesce(new.client_user, old.client_user, current_user);
    new.client_role = coalesce(new.client_role, old.client_role, current_role);
    new.client_protocol = coalesce(new.client_protocol, old.client_protocol, rdb$get_context('SYSTEM', 'NETWORK_PROTOCOL'));
    new.client_version = coalesce(new.client_version, old.client_version, rdb$get_context('USER_SESSION', 'DBMON_CLIENT_VERSION'));
    new.client_os_user = coalesce(new.client_os_user, old.client_os_user, rdb$get_context('USER_SESSION', 'DBMON_CLIENT_OS_USER'));
    new.server_pid = coalesce(new.server_pid, old.server_pid, rdb$get_context('USER_SESSION', 'DBMON_SERVER_PID'));
    new.auth_method = coalesce(new.auth_method, old.auth_method, rdb$get_context('USER_SESSION', 'DBMON_AUTH_METHOD'));

    new.session_id = coalesce(new.session_id, old.session_id, current_connection);
    new.transaction_id = coalesce(new.transaction_id, old.transaction_id, current_transaction);
    new.isolation_level = coalesce(new.isolation_level, old.isolation_level, rdb$get_context('SYSTEM', 'ISOLATION_LEVEL'));
    new.client_pid = coalesce(new.client_pid, old.client_pid, rdb$get_context('SYSTEM', 'CLIENT_PID'));
    new.engine_version = coalesce(new.engine_version, old.engine_version, rdb$get_context('SYSTEM', 'ENGINE_VERSION'));

    log_attachement_client_os_user = (select iif(val similar to '0|1', val, 0) from dbmon_settings where key = 'log_attachement_client_os_user');
    log_attachement_client_version = (select iif(val similar to '0|1', val, 0) from dbmon_settings where key = 'log_attachement_client_version');
    log_attachement_server_pid = (select iif(val similar to '0|1', val, 0) from dbmon_settings where key = 'log_attachement_server_pid');
    log_attachement_auth_method = (select iif(val similar to '0|1', val, 0) from dbmon_settings where key = 'log_attachement_auth_method');
    if (nullif(trim(new.client_os_user), '') is null and log_attachement_client_os_user > 0
            or nullif(trim(new.client_version), '') is null and log_attachement_client_version > 0
            or nullif(trim(new.server_pid), '') is null and log_attachement_server_pid > 0
            or nullif(trim(new.auth_method), '') is null and log_attachement_auth_method > 0
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
        if (new.client_version is not null)
            then rdb$set_context('USER_SESSION', 'DBMON_CLIENT_VERSION', new.client_version);
        if (new.client_os_user is not null)
            then rdb$set_context('USER_SESSION', 'DBMON_SERVER_PID', new.server_pid);
        if (new.client_os_user is not null)
            then rdb$set_context('USER_SESSION', 'DBMON_AUTH_METHOD', new.auth_method);
    end

    log_call_stack = (select iif(val similar to '0|1', val, 0) from dbmon_settings where key = 'log_call_stack');
    if (new.call_stack is null
        and (log_call_stack > 0
                or exists(select *
                            from dbmon_tracked_field as tf
                            where tf.table_name = new.table_name
                                and tf.field_name in (new.changed_field_name, '*', '?')
                                and coalesce(tf.log_call_stack, 0) > 0)
        )
    ) then
    begin
        new.call_stack = '';

        for select
                cs.mon$call_id, cs.mon$caller_id
                , cs.mon$object_name, cs.mon$object_type, cs.mon$timestamp
                , cs.mon$source_line, cs.mon$source_column
          from mon$statements as s
              inner join mon$call_stack as cs using(mon$statement_id)
          where s.mon$attachment_id = current_connection
              or s.mon$transaction_id = rdb$get_context('SYSTEM', 'TRANSACTION_ID')
          order by mon$call_id asc
          into call_stack_call_id, call_stack_caller_id
                , call_stack_object_name, call_stack_object_type, call_stack_timestamp
                , call_stack_source_line, call_stack_source_column
        do
        begin
           new.call_stack = left(new.call_stack
                                    || call_stack_call_id || '(' || call_stack_timestamp || '): '
                                    || upper(decode(call_stack_object_type
                                                    , 0, 'table'
                                                    , 1, 'view'
                                                    , 2, 'trigger'
                                                    , 3, 'computed column'
                                                    , 4, 'constraint'
                                                    , 5, 'procedure'
                                                    , 6, 'index expression'
                                                    , 7, 'exception'
                                                    , 8, 'user'
                                                    , 9, 'domain'
                                                    , 10, 'index'
                                                    , 14, 'sequence'
                                                    , 15, 'udf'
                                                    , 17, 'collation'
                                                    , 'unknown:' || call_stack_object_type))
                                    || ' '
                                    || trim(coalesce(call_stack_object_name, 'null'))
                                    || '[' || coalesce(call_stack_source_line, 'null')
                                            || ':'
                                            || coalesce(call_stack_source_column, 'null')
                                        || ']'
                                    || ' called by ' || coalesce(call_stack_caller_id, 'null')
                                    || ascii_char(13) || ascii_char(10)
                                , 4096);
        end
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

    if (nullif(trim(new.primary_key_fields), '') is null) then
    begin
        new.primary_key_fields = '';

        for select
                trim(idxs.rdb$field_name) as field_name
            from rdb$relation_constraints as c
                inner join rdb$indices as idx on idx.rdb$index_name = c.rdb$index_name
                inner join rdb$index_segments as idxs on idxs.rdb$index_name = idx.rdb$index_name
            where c.rdb$relation_name = new.table_name
                and c.rdb$constraint_type containing 'primary key'
            order by idxs.rdb$field_position
            into field_name
        do
        begin
            new.primary_key_fields = left(trim(new.primary_key_fields || field_name) || ';', 1024);
        end
    end

    when any do
    begin
    end
end^

set term ; ^

comment on trigger dbmon_data_changelog_bui is 'Trigger to calculate default values for some columns if they have not been passed.
See https://github.com/atronah/firebird_utils/tree/master/dbmon for details.';