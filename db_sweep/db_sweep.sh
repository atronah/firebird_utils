#!/usr/bin/env bash

rdb_bin=/opt/firebird/bin
db=127.0.0.1:box_med
db_user=SYSDBA
db_password=masterkey
gstat_log=/home/share/logs/gstat.log

pushd "$(dirname "$0")"

echo "========> connections at $(date +%Y-%m-%d\ %H:%M:%S) for $db <========" >> $gstat_log
# example of count_connections.sql
## select
##     count(*) as all_conections
##     , count(iif(mon$timestamp < cast(dateadd(-1 day to current_date) || ' 22:00:00' as timestamp)
##             , mon$attachment_id
##             , null)
##     ) as old_connections
## from mon$attachments;
$rdb_bin/isql -user $db_user -pas $db_password -i ./count_connections.sql $db >> $gstat_log


#echo "========> detach all and execute special script $(date +%Y-%m-%d\ %H:%M:%S) for $db <========" >> $gstat_log
#$rdb_bin/isql -user $db_user -pas $db_password -i ./detach_all.sql $db
#$rdb_bin/isql -user $db_user -pas $db_password -i ./after_detach_all.sql $db

echo "========> detaching old connections $(date +%Y-%m-%d\ %H:%M:%S) for $db <========" >> $gstat_log
# example of detach_old_connections.sql
## delete from mon$attachments where mon$timestamp < cast(dateadd(-1 day to current_date) || ' 22:00:00' as timestamp); commit;
$rdb_bin/isql -user $db_user -pas $db_password -i ./detach_old_connections.sql $db

echo "========> connections after detaching at $(date +%Y-%m-%d\ %H:%M:%S) for $db <========" >> $gstat_log
$rdb_bin/isql -user $db_user -pas $db_password -i ./count_connections.sql $db >> $gstat_log

echo "========> start sweeping at $(date +%Y-%m-%d\ %H:%M:%S) for $db <========" >> $gstat_log
$rdb_bin/gfix -user $db_user -pas $db_password -sweep $db

echo "========> gstat after $(date +%Y-%m-%d\ %H:%M:%S) for $db <========" >> $gstat_log
$rdb_bin/gstat -header $db >> $gstat_log

sync && echo 3 > /proc/sys/vm/drop_caches

popd
