set list on;
select
    mon$user
    , datediff(day from mon$timestamp to current_timestamp) as days_old
    , count(*) as cnt
    , min(mon$timestamp) as min_timestamp
from mon$attachments
where coalesce(mon$system_flag, 0) = 0
group by 1, 2;