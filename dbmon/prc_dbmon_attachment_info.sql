set term ^ ;
create or alter procedure dbmon_attachment_info(
    table_name type of column dbmon_tracked_field.table_name = null
    , field_name type of column dbmon_tracked_field.field_name = null
)
returns (
    server_pid type of column dbmon_structure_changelog.server_pid
    , auth_method type of column dbmon_structure_changelog.auth_method
    , client_version type of column dbmon_structure_changelog.client_version
    , client_os_user type of column dbmon_structure_changelog.client_os_user
    , logging_mode type of column dbmon_tracked_field.attachment_info_logging_mode
    , table_field_logging_mode type of column dbmon_tracked_field.attachment_info_logging_mode
    , user_query type of column dbmon_tracked_field.attachment_info_user_query
    , table_field_user_query type of column dbmon_tracked_field.attachment_info_user_query
)
as
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master/dbmon

    logging_mode = (select s.val from dbmon_settings as s where s.key = 'attachment_info_logging_mode');

    -- 3 - log using data from user query (specified in setting `attachment_info_view`)
    if (logging_mode = 3)
        then user_query = (select s.val from dbmon_settings as s where s.key = 'attachment_info_user_query');


    if (table_name > '') then
    begin
        for select
                tf.attachment_info_logging_mode, tf.attachment_info_user_query
            from dbmon_tracked_field as tf
            where tf.table_name = upper(trim(replace(:table_name, '''', '''''')))
                and (tf.field_name = upper(trim(replace(:field_name, '''', '''''')))
                    or tf.field_name = '*')
                and tf.attachment_info_logging_mode is not null
            order by iif(tf.field_name = upper(trim(replace(:field_name, '''', ''''''))), 0, 1) asc
            into table_field_logging_mode, table_field_user_query
        do
        begin
            logging_mode = table_field_logging_mode;
            -- 3 - log using data from user query (specified in field `dbmon_tracked_field.attachment_info_user_query`)
            if (table_field_logging_mode = 3)
                then user_query = table_field_user_query;
        end
    end

    -- logging_mode = 0 - disable logging
    if (logging_mode = 0)
        then exit;



    -- 2 - log with caching (in context variables)
    if (logging_mode = 2) then
    begin
        server_pid = rdb$get_context('USER_SESSION', 'DBMON_SERVER_PID');
        auth_method = rdb$get_context('USER_SESSION', 'DBMON_AUTH_METHOD');
        client_version = rdb$get_context('USER_SESSION', 'DBMON_CLIENT_VERSION');
        client_os_user = rdb$get_context('USER_SESSION', 'DBMON_CLIENT_OS_USER');
    end

    -- 3 - log using data from user query (specified in setting `attachment_info_view`)
    if (logging_mode = 3) then
    begin
        if (user_query > '') then
        begin
            execute statement 'select
                                    server_pid
                                    , auth_method
                                    , client_version
                                    , client_os_user
                                from (' || user_query || ')
                                rows 1'
                into server_pid, auth_method, client_version, client_os_user;
        end
        else client_os_user = 'ERROR: Not specified user query for logging_mode = 3';
    end

    -- 1 - log without caching (in context variables)
    if (logging_mode = 1
        -- 2 - log with caching (in context variables)
        or logging_mode = 2
            and server_pid is null
            and auth_method is null
            and client_version is null
            and client_os_user is null
    ) then
    begin
        select
                a.mon$server_pid, a.mon$auth_method, a.mon$client_version, a.mon$remote_os_user
            from mon$attachments as a
            where a.mon$attachment_id = current_connection
            into server_pid, auth_method, client_version, client_os_user;

        if (logging_mode = 2
                and (server_pid is not null
                        or auth_method is not null
                        or client_version is not null
                        or client_os_user is not null
                )
        ) then
        begin
            rdb$set_context('USER_SESSION', 'DBMON_SERVER_PID', :server_pid);
            rdb$set_context('USER_SESSION', 'DBMON_AUTH_METHOD', :auth_method);
            rdb$set_context('USER_SESSION', 'DBMON_CLIENT_VERSION', :client_version);
            rdb$set_context('USER_SESSION', 'DBMON_CLIENT_OS_USER', :client_os_user);
        end
    end

    suspend;

    when any do
    begin
        client_os_user = 'EXCEPTION: '
                            ||'SQLCODE=' || coalesce(SQLCODE, 'null')
                            ||'; GDSCODE=' || coalesce(GDSCODE, 'null')
                            ||'; SQLSTATE=' || coalesce(SQLSTATE, 'null');
        suspend;
    end
end^

set term ; ^