select
    s.mon$statement_id as stmt_id,
    s.mon$sql_text as stmt,
    (select t.rdb$type_name from rdb$types as t where t.rdb$field_name = 'MON$STATE' and t.rdb$type = s.mon$state) as status,
    s.mon$timestamp as started,
    rs.mon$record_seq_reads as non_indexed_reads,
    rs.mon$record_idx_reads as indexed_reads,
    rs.mon$record_inserts as inserts,
    rs.mon$record_updates as updates,
    rs.mon$record_deletes as deletes,

    s.mon$transaction_id as trans_id,
    s.mon$attachment_id as atach_id,
    right(a.mon$remote_process, 32) as process_name,

    rs.mon$record_backouts as "Records Backed Out",
    rs.mon$record_purges as "Records Purged",
    rs.mon$record_expunges as "Records Expunged",
    io.mon$page_reads as "Page Reads",
    io.mon$page_writes as "Page Writes",
    io.mon$page_fetches as "Page Fetches",
    io.mon$page_marks as "Page Marks",

    a.mon$remote_process as remote_process,
    'delete from mon$statements where mon$statement_id = ' || s.mon$statement_id as delete_stmt
from mon$statements as s
    inner join mon$record_stats as rs on rs.mon$stat_id = s.mon$stat_id
    inner join mon$attachments as a on a.mon$attachment_id = s.mon$attachment_id
    left join mon$io_stats as io on io.mon$stat_id = s.mon$stat_id
where
    -- Фильтр по содержимому запроса
    (cast(:sql_part as varchar(1024)) = '' or s.mon$sql_text containing :sql_part)
    -- фильтр "PID процесса на сервере Firebird"
    and (cast(:server_pid as bigint) is null or a.mon$server_pid = :server_pid)
    -- фильтр "Только активные"
    and (coalesce(cast(:only_active as smallint), 0) = 0 or s.mon$state is distinct from 0)