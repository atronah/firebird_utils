update dbmon_settings as s
    set s.key = 'log_attachment_client_os_user'
    where s.key = 'log_attachement_client_os_user';

update dbmon_settings as s
    set s.key = 'log_attachment_client_version'
    where s.key = 'log_attachement_client_version';

update dbmon_settings as s
    set s.key = 'log_attachment_server_pid'
    where s.key = 'log_attachement_server_pid';

update dbmon_settings as s
    set s.key = 'log_attachment_auth_method'
    where s.key = 'log_attachement_auth_method';