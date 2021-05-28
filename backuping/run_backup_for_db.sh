#! /bin/sh

scriptpath="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

rdb="/opt/RedDatabase/bin/gbak"
db_host=127.0.0.1/3050
db_alias=$1; shift
db_user=SYSDBA
db_pswd=masterkey
outdir="/home/backups/outdir/$db_alias"
workdir="/home/backups/temp/$db_alias"
mover="$scriptpath/$1"; shift
notifier="$scriptpath/$1"; shift

#echo "[$(date +%Y-%m-%d\ %H:%M:%S)] force removing workdir: ${workdir}"
#rm -rf "${workdir}"

# runs db_autobackup.sh in specific environment for specific datavase
# example of using:
# > run_backup_for_db.sh my_db my_mover.sh my_notifier.sh -s
# runs backup for database `my_db` with skipping restore (option `-s` passed into db_autobackup.sh)
# with `my_mover.sh` and `my_notifier.sh` as scripts to move result archive and notify about problems

$scriptpath/db_autobackup.sh -d $db_alias -g "$rdb" -h $db_host -u $db_user -p $db_pswd -o "$outdir" -w "$workdir" -m "$mover" -n "$notifier" $@
