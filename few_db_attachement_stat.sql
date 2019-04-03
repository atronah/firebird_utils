execute block
returns(
    db_path varchar(255)
    , remote_address type of column mon$attachments.mon$remote_address
    , remote_process type of column mon$attachments.mon$remote_process
    , total_attachments_count bigint
    , active_attachments_count bigint
)
as
declare db_user varchar(255);
declare db_password varchar(255);
begin

    for select
            trim(db_path) as db_path
            , trim(db_user) as db_user
            , trim(db_password) as db_password
        from (
            select 'localhost:db' as db_path, 'SYSDBA' as db_user, 'masterkey' as db_password from rdb$database
        )
        into db_path, db_user, db_password
    do
    begin
        for execute statement 'select
            a.mon$remote_address
            , a.mon$remote_process
            , count(distinct a.mon$attachment_id) as total_attachments_count
            , count(distinct iif(a.mon$state = 1, a.mon$attachment_id, null)) as active_attachments_count
        from mon$attachments as a
        group by 1, 2'
        on external db_path as user db_user password db_password role current_role
        into remote_address, remote_process, total_attachments_count, active_attachments_count
        do suspend;
    end
end

