SELECT tr.mon$transaction_id as "Tr. ID", 
       tr.mon$attachment_id as "Attachment ID", 
       case
         when tr.mon$state = 1 then 'STARTED'
         when tr.mon$state = 0 then 'FINISHED'
       end as "State",
       tr.mon$timestamp as "Started At", 
       tr.mon$top_transaction as "Top Tr.", 
       tr.mon$oldest_transaction "Oldest Tr.", 
       tr.mon$oldest_active "Oldest Active Tr.", 
       case
         when tr.mon$isolation_mode = 0 then 'consistence'
         when tr.mon$isolation_mode = 1 then 'concurrency'
         when tr.mon$isolation_mode = 2 then 'read committed record version'
         when tr.mon$isolation_mode = 3 then 'read committed no record version'
       end as "Isolation Mode",
       case
         when tr.mon$lock_timeout = -1 then 'Infinite wait'
         when tr.mon$lock_timeout = 0 then 'No wait'
         when tr.mon$lock_timeout > 0  then 'Timeout ' || mon$lock_timeout
       end as "Lock Timeout",
       case
         when tr.mon$read_only = 0 then 'No'
         when tr.mon$read_only = 1 then 'Yes'
       end as "Read Only",
       case
         when tr.mon$auto_commit = 0 then 'No'
         when tr.mon$auto_commit = 1 then 'Yes'
       end as "Auto Commit",
       case
         when tr.mon$auto_undo = 0 then 'No'
         when tr.mon$auto_undo = 1 then 'Yes'
       end as "Auto Undo",
       r.mon$record_seq_reads as "Non-indexed Reads",
       r.mon$record_idx_reads as "Indexed Reads",
       r.mon$record_inserts as "Records Inserted",
       r.mon$record_updates as "Records Updated",
       r.mon$record_deletes as "Records Deleted",
       r.mon$record_backouts as "Records Backed Out",
       r.mon$record_purges as "Records Purged",
       r.mon$record_expunges as "Records Expunged",
       io.mon$page_reads as "Page Reads",
       io.mon$page_writes as "Page Writes",
       io.mon$page_fetches as "Page Fetches",
       io.mon$page_marks as "Page Marks"
FROM mon$transactions tr
left join mon$record_stats r on (tr.mon$stat_id = r.mon$stat_id)
left join mon$io_stats io on (tr.mon$stat_id = io.mon$stat_id)
order by tr.mon$timestamp