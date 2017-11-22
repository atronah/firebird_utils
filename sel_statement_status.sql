select
    s.mon$sql_text
    , s.mon$timestamp
    , s.mon$statement_id
    , rs.mon$record_seq_reads as non_indexed_reads
    , rs.mon$record_idx_reads as indexed_reads
    , rs.mon$record_inserts as inserts
    , rs.mon$record_updates as updates
    , rs.mon$record_deletes as updates
from mon$statements as s
inner join mon$record_stats as rs on rs.mon$stat_id = s.mon$stat_id
where s.mon$sql_text containing :sql_part