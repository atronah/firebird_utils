merge into dbmon_settings as cur
    using (
        select
            trim(k) as key, trim(v) as val, trim(d) as description
        from (
            select 'attachment_info_logging_mode' as k, 0 as v
                , 'Specifies mode of logging info from system table `mon$attachments`
into fields `client_version`, `client_os_user`, `server_pid` and `auth_method`
of tables `dbmon_structure_changelog` and `dbmon_data_changelog`.

Available values:
- 0 - disable logging
- 1 - log without caching (in context variables)
- 2 - log with caching (in context variables)
- 3 - log using data from user query (specified in setting `attachment_info_view`)
' as d
            from rdb$database
            union
            select 'attachment_info_user_query' as k, null as v
                , 'User query to get attachment info, that should return the following fields:
- `server_pid`
- `client_os_user`
- `client_version`
- `auth_method`
' as d
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