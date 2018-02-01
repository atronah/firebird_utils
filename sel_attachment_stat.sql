SELECT a.mon$attachment_id as "Attachment ID", 
       a.mon$state as "State", 
       a.mon$attachment_name as "Attachment Name", 
       a.mon$remote_address as "Remote Address", 
       a.mon$timestamp as "Established At", 
       a.mon$remote_process as "Remote Process", 
       r.mon$record_seq_reads as "Non-indexed Reads",
       r.mon$record_idx_reads as "Indexed Reads",
       r.mon$record_inserts as "Records Inserted",
       r.mon$record_updates as "Records Updated",
       r.mon$record_deletes as "Records Deleted",
       r.mon$record_backouts as "Records Backed Out",
       r.mon$record_purges as "Records Purged",
       r.mon$record_expunges as "Records Expunged",
       count(distinct iif(tr.mon$lock_timeout = -1, tr.mon$transaction_id, null)) as infinite_waits,
       count(distinct iif(tr.mon$lock_timeout = 0, tr.mon$transaction_id, null)) as no_waits,
       count(distinct iif(tr.mon$lock_timeout > 0, tr.mon$transaction_id, null)) as waits
from mon$attachments as a
    inner join rdb$character_sets as cs on a.mon$character_set_id = cs.rdb$character_set_id
    left join mon$record_stats as r on a.mon$stat_id = r.mon$stat_id
    left join mon$transactions as tr on tr.mon$attachment_id = a.mon$attachment_id
                                            and tr.mon$state = 1 -- 'STARTED'
where (coalesce(:transaction_id, 0) = 0 or tr.mon$transaction_id = :transaction_id)
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14