merge into dbmon_settings as cur
    using (
        select
            trim(k) as key, trim(v) as val, trim(d) as description
        from (
            select 'log_attachment_client_os_user' as k, 0 as v
                , 'Enables saving info from `mon$attachments.mon$remote_os_user` to `client_os_user` field of tables `dbmon_structure_changelog` and `dbmon_data_changelog`.' as d
            from rdb$database
            union
            select 'log_attachment_client_version' as k, 0 as v
                , 'Enables saving info from `mon$attachments.mon$client_version` to `client_version` field of tables `dbmon_structure_changelog` and `dbmon_data_changelog`.' as d
            from rdb$database
            union
            select 'log_attachment_server_pid' as k, 0 as v
                , 'Enables saving info from `mon$attachments.mon$server_pid` to `server_pid` field of tables `dbmon_structure_changelog` and `dbmon_data_changelog`.' as d
            from rdb$database
            union
            select 'log_attachment_auth_method' as k, 0 as v
                , 'Enables saving info from `mon$attachments.mon$auth_method` to `auth_method` field of tables `dbmon_structure_changelog` and `dbmon_data_changelog`.' as d
            from rdb$database
            union
            select 'log_context_variables' as k, '' as v
                , 'Semicolon separated list of context variables (in format `<NAME_SPACE>.<VARIABLE_NAME>`) which should be logged into field `context_variables`  of tables `dbmon_structure_changelog` and `dbmon_data_changelog`.' as d
            from rdb$database
            union
            select 'log_call_stack' as k, 0 as v
                , 'Enables saving info from `mon$call_stack` to `call_stack` field of tables `dbmon_structure_changelog` and `dbmon_data_changelog`.' as d
            from rdb$database
            union
            select 'log_prev_unified_create_statement' as k, 0 as v
                , 'Enables computing create statement for previous version ob database object (before update)'
                || ' using procedure `aux_get_create_statement`'
                || ' and saving result into `prev_unified_create_statement` field of `dbmon_structure_changelog`' as d
            from rdb$database
        )
    ) as upd
    on cur.key = upd.key
    when not matched
        then insert (key, val, description) values (upd.key, upd.val, upd.description)
    when matched then update set cur.description = upd.description;