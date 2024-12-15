create sequence aux_conection_whitelist_seq;

create table aux_conection_whitelist (
    record_id bigint
    , allowed_process varchar(1024)
    , allowed_user varchar(255)
    , allowed_address varchar(255)

    , constraint pk_aux_conection_whitelist primary key (record_id)
);

/*
insert into aux_conection_whitelist (record_id, allowed_process, allowed_user, allowed_address)
    values (next value for aux_conection_whitelist_seq, 'my_process.exe', 'my_user', '127.0.0.1/3050');
*/

set term ^ ;

create trigger aux_connection_check
    active on connect
    position 0
as
declare system_flag type of column mon$attachments.mon$system_flag;
declare remote_process type of column mon$attachments.mon$remote_process;
declare db_user type of column mon$attachments.mon$user;
declare remote_address type of column mon$attachments.mon$remote_address;

declare allowed_process type of column aux_conection_whitelist.allowed_process;
declare allowed_user type of column aux_conection_whitelist.allowed_user;
declare allowed_address type of column aux_conection_whitelist.allowed_address;

declare process_length bigint;
begin
    select
            mon$system_flag, mon$remote_process, mon$user, mon$remote_address
        from mon$attachments
        where mon$attachment_id = current_connection
        into system_flag, remote_process, db_user, remote_address;

    if (system_flag > 0)
        then exit;

    if (not exists(select *
                    from aux_conection_whitelist
                    where (allowed_process is not null
                        or allowed_user is not null
                        or allowed_address is not null))
    ) then exit;

    -- white list
    for select
            allowed_process, allowed_user, allowed_address
        from aux_conection_whitelist
        into allowed_process, allowed_user, allowed_address
    do
    begin
        process_length = char_length(allowed_process);
        if ((allowed_process is null or upper(right(remote_process, process_length)) = upper(allowed_process))
            and (allowed_user is null or upper(db_user) = upper(allowed_user))
            and (allowed_address is null or upper(remote_address) = upper(allowed_address))
        ) then exit;
    end

    execute procedure raise_exception('Access denied for (see table aux_conection_whitelist)');
end^

set term ; ^