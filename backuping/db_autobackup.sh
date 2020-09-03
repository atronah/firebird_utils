#! /bin/sh

fb_gbak="/opt/firebird/bin/gbak"
zipper=7za
error_pattern="\s\+ERROR:"

db_host=127.0.0.1/3050
db_alias=box_med
db_user=SYSDBA
db_password=masterkey

out_dir="/var/db/backups/auto"
work_dir="/var/db/backups/auto/tmp"


# Parse arguments
while getopts ":g:h:d:u:p:o:w:m:n:z:e:" opt; do
    case $opt in
        g) fb_gbak="$OPTARG"
        ;;
        h) db_host="$OPTARG"
        ;;
        d) db_alias="$OPTARG"
        ;;
        u) db_user="$OPTARG"
        ;;
        p) db_password="$OPTARG"
        ;;
        o) out_dir="$OPTARG"
        ;;
        w) work_dir="$OPTARG"
        ;;
        m) mover="$OPTARG"
        ;;
        n) notifier="$OPTARG"
        ;;
        z) zipper="$OPTARG"
        ;;
        e) error_pattern="$OPTARG"
        ;;
        \?) echo "Invalid option -$OPTARG" >&2
        echo "usage: db_autobackup.sh [arguments]"
        echo ""
        echo "arguments:"
        echo "-g /opt/firebird/gbak                     path to gbak utility of firebird/reddatabase instance"
        echo "-h 127.0.0.1/3050                         host with port"
        echo "-d box_med                                database alias, which is used for connect to db and make names of bachup/restore/archive file"
        echo "-u SYSDBA                                 database user name"
        echo "-p masterkey                              database user password"
        echo "-o /var/db/backups/auto                   path to dir for result archive and ERROR.logs"
        echo "-w /var/db/backups/auto/tmp               path to working dir for all temporary files (WARNING: all files in it can be deleted)"
        echo "-m /var/db/backups/scripts/mover.sh       path to script for moving resulting archive (should receive archive fullpath as single argument)"
        echo "-n /var/db/backups/scripts/notifier.sh    path to script for notifying about errors (should receive message as single argument)"
        echo "-z 7za                                    7z util name or path"
        exit 1
        ;;
    esac
done

backup_fullpath="$work_dir/$db_alias"_$(date +%Y%m%d_%H%M).fbk
archive_name="$db_alias"_$(date +%d).7z
restore_fullpath="${backup_fullpath/\.fbk/}".fdb

echo ""
echo "[$(date +%Y-%m-%d\ %H:%M:%S)] starting script db_autobackup with follow parameters:"
echo "gbak:                 $fb_gbak"
echo "db:                   $db_host:$db_alias -user $db_user -password $db_password"
echo "output dir:           $out_dir"
echo "work dir:             $work_dir"
echo "backup fullpath:      $backup_fullpath"
echo "restore fullpath:     $restore_fullpath"
echo "archive name:         $archive_name"


if [ ! -d "$out_dir" ]; then
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] creating output directory (because it doesn't exist): $out_dir"
    mkdir -p "$out_dir"
fi

if [ ! -d "$work_dir" ]; then
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] creating working directory (because it doesn't exist): $work_dir"
    mkdir -p "$work_dir"
fi


echo "[$(date +%Y-%m-%d\ %H:%M:%S)] changing working directory to: $work_dir"
pushd "$work_dir"


echo "[$(date +%Y-%m-%d\ %H:%M:%S)] starting backup for ${db_host}:${db_alias} into $backup_fullpath"
$fb_gbak -user $db_user -password $db_password -b -g -v "${db_host}:${db_alias}" "$backup_fullpath" -y "$backup_fullpath".log
echo "[$(date +%Y-%m-%d\ %H:%M:%S)] backup has been finished"
if grep -e "$error_pattern" "$backup_fullpath".log; then
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] ERROR during backup"

    if [[ -n $notifier ]] ; then
        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] calling notifier $notifier"
        $notifier "Database backup error: $(grep -e "$error_pattern" "$backup_fullpath".log)"
    fi

    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] moving ${backup_fullpath}.log to ${out_dir}/ERROR_$(basename $backup_fullpath).log"
    mv "$backup_fullpath".log "$out_dir/ERROR_$(basename $backup_fullpath)".log
else
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] removing old ${db_alias}.fdb from $out_dir"
    rm -f "${out_dir}/$db_alias".fdb

    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] starting restore for $backup_fullpath into $restore_fullpath"
    $fb_gbak -user $db_user -password $db_password -c -v "$backup_fullpath" "$restore_fullpath" -y "$restore_fullpath".log
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] restore has been finished"

    if grep -e "$error_pattern" "$restore_fullpath".log; then
        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] ERROR during restore"

        if [[ -n $notifier ]] ; then
            echo "[$(date +%Y-%m-%d\ %H:%M:%S)] calling notifier $notifier"
            $notifier "Database restore error: $(grep -e "$error_pattern" "$restore_fullpath".log)"
        fi

        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] moving ${restore_fullpath}.log to ${out_dir}/ERROR_$(basename $restore_fullpath).log"
        mv "$restore_fullpath".log "$out_dir/ERROR_$(basename $restore_fullpath)".log
    else
        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] append size info to ${out_dir}/${db_alias}.sizelog"
        ls -lhs "${restore_fullpath}" >> "${out_dir}/$db_alias".sizelog

        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] force renaming ${restore_fullpath} to ${out_dir}/${db_alias}.fdb"
        mv -f "$restore_fullpath" "${out_dir}/$db_alias".fdb

        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] force renaming ${restore_fullpath}.log to ${out_dir}/${db_alias}.fdb.log"
        mv -f "$restore_fullpath".log "${out_dir}/$db_alias".fdb.log
    fi

    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] making archive $archive_name for $backup_fullpath"
    $zipper a "$archive_name" "$backup_fullpath" "$backup_fullpath".log "$restore_fullpath".log

    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] force moving ${archive_name} to ${out_dir}/${archive_name}"
    mv -f "$archive_name" "$out_dir/$archive_name"

    if [[ -n $mover ]] ; then
        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] calling mover $mover"
        $mover "$out_dir/$archive_name"
    fi

    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] clean $work_dir"
    rm ./*
fi


echo "[$(date +%Y-%m-%d\ %H:%M:%S)] force removing ${backup_fullpath} and ${backup_fullpath}.log"
rm -f "$backup_fullpath" "$backup_fullpath".log

echo "[$(date +%Y-%m-%d\ %H:%M:%S)] restore working directory"
popd

