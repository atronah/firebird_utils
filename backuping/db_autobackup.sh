#! /bin/sh

# author: atronah (look for me by this nickname on GitHub and GitLab)
# source: https://github.com/atronah/firebird_utils

fb_gbak="/opt/firebird/bin/gbak"
zipper=7za
error_pattern="\s\+ERROR:"

db_host=127.0.0.1/3050
db_user=SYSDBA
db_password=masterkey

out_dir="/var/db/backups/auto"
work_dir="/var/db/backups/auto/tmp"
restore_with_replace=""
skip_restore="F"
through_console="F"
parallel=""


# Parse arguments
# no collon at start means Verbose Mode (getopts handle and prints errors)
# collon after option means that it has an argument
while getopts "g:h:d:u:p:o:w:m:n:z:e:r:x:isc" opt; do
    case ${opt} in
        g) fb_gbak="${OPTARG}"
        ;;
        h) db_host="${OPTARG}"
        ;;
        d) db_alias="${OPTARG}"
        ;;
        u) db_user="${OPTARG}"
        ;;
        p) db_password="${OPTARG}"
        ;;
        o) out_dir="${OPTARG}"
        ;;
        w) work_dir="${OPTARG}"
        ;;
        m) mover="${OPTARG}"
        ;;
        n) notifier="${OPTARG}"
        ;;
        z) zipper="${OPTARG}"
        ;;
        e) error_pattern="${OPTARG}"
        ;;
        r) restore_dir="${OPTARG}"
        ;;
        x) parallel="-par ${OPTARG}"
        ;;
        i) restore_with_replace="-rep"
        ;;
        s) skip_restore="T"
        ;;
        c) through_console="T";
           skip_restore="T"
        ;;
        \?) echo "Invalid option -${OPTARG}" >&2
        echo "usage: db_autobackup.sh [arguments]"
        echo ""
        echo "arguments:"
        echo "-g GBAK_PATH                              path to gbak utility of firebird/reddatabase instance (default: ${fb_gbak})"
        echo "-h DB_HOST                                host with port to connect to database (default: ${db_host})"
        echo "-d DB_ALIAS                               database alias, which is used for connect to db and make names of bachup/restore/archive file"
        echo "-u DB_USER                                database user name to connect to database (default: ${db_user})"
        echo "-p DB_PASSWORD                            database user password to connect to database (default: ${db_password})"
        echo "-o OUT_DIR                                path to dir for result archive and ERROR.logs (default: ${out_dir})"
        echo "-w WORK_DIR                               path to working dir for all temporary files (WARNING: all files in it can be deleted) (default: ${work_dir})"
        echo "-m PATH_TO_MOVE_SCRIPT                    path to script for moving resulting archive (should receive archive fullpath as single argument)"
        echo "-n PATH_TO_NOTIFY_SCRIPT                  path to script for notifying about errors (should receive message as single argument)"
        echo "-z ZIPPER                                 7z util name or path (default: ${zipper})"
        echo "-r RESTORE_DIR                            directory for restore (default: work directory if not specified, i.e. ${work_dir})"
        echo "-x WORKERS_NUMBER                         use WORKERS_NUMBER parralel workers (default: not use at all)"
        echo "-i                                        restore with replace (inplace), i.e. using -rep option (default: false)"
        echo "-s                                        skip restore"
        echo "-c                                        through console: making backup direct to 7z archive without creating .fbk file"
        exit 1
        ;;
    esac
done


if [[ -z "${db_alias}" ]] ; then
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] db alias not specified"
    exit 1
fi


if [ ! -d "${out_dir}" ]; then
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] creating output directory (because it doesn't exist): ${out_dir}"
    mkdir -p "${out_dir}"
fi

work_dir="${work_dir}/${db_alias}"

if [ ! -d "${work_dir}" ]; then
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] creating working directory (because it doesn't exist): ${work_dir}"
    mkdir -p "${work_dir}"
fi

time_suffix=$(date +%Y%m%d_%H%M)
backup_fullpath="${work_dir}/${db_alias}_${time_suffix}".fbk

archive_name="${db_alias}"_$(date +%d).7z

if [ ! -d "${restore_dir}" ]; then
    restore_dir="${work_dir}"
fi

if [[ -z "${restore_with_replace}" ]]; then
    restore_fullpath="${restore_dir}/${db_alias}_${time_suffix}".fdb
else
    restore_fullpath="${out_dir}/${db_alias}.fdb"
fi
restore_log_fullpath="${restore_dir}/${db_alias}_${time_suffix}".fdb.log


echo ""
echo "[$(date +%Y-%m-%d\ %H:%M:%S)] starting script db_autobackup with follow parameters:"
echo "gbak:                 ${fb_gbak}"
echo "db:                   ${db_host}:${db_alias} -user ${db_user} -password ${db_password}"
echo "output dir:           ${out_dir} (used $(df -h ${out_dir} | awk 'NR>1 {print $3 " of " $2 ", " $5}'))"
echo "work dir:             ${work_dir} (used $(df -h ${work_dir} | awk 'NR>1 {print $3 " of " $2 ", " $5}'))"
echo "backup fullpath:      ${backup_fullpath}"
echo "restore fullpath:     ${restore_fullpath}"
echo "restore log fullpath: ${restore_log_fullpath}"
echo "archive name:         ${archive_name}"
echo "parallel:             ${parallel}"
echo "skip restore:         ${skip_restore}"
echo "through console:      ${through_console}"


if [ "$(ls -A ${work_dir})" ]; then
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] ERROR: ${work_dir} is not Empty. Clean it before."
    if [[ -n ${notifier} ]] ; then
        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] calling notifier ${notifier}"
        ${notifier} "ERROR during database backuping: working directory is not empty: ${work_dir}"
    fi
    exit 1
fi

echo "[$(date +%Y-%m-%d\ %H:%M:%S)] changing working directory to: ${work_dir}"
pushd "${work_dir}"

if [ "${through_console}" != "T" ]; then
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] starting backup for ${db_host}:${db_alias} into ${backup_fullpath}"
    ${fb_gbak} -user ${db_user} -password ${db_password} -b -g -v ${parallel} "${db_host}:${db_alias}" "${backup_fullpath}" -y "${backup_fullpath}".log
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] backuping has been finished"
else
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] starting backup for ${db_host}:${db_alias} direct into ${archive_name}"
    ${fb_gbak} -user ${db_user} -password ${db_password} -b -g -v ${parallel} "${db_host}:${db_alias}" stdout -y "${backup_fullpath}".log | ${zipper} a -si ${archive_name}
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] backuping and compressing has been finished"
fi

if grep -e "${error_pattern}" "${backup_fullpath}".log; then
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] ERROR during backup"

    if [[ -n ${notifier} ]] ; then
        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] calling notifier ${notifier}"
        ${notifier} "Database backup error: $(grep -e "${error_pattern}" "${backup_fullpath}".log)"
    fi

    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] moving ${backup_fullpath}.log to ${out_dir}/ERROR_$(basename ${backup_fullpath}).log"
    mv "${backup_fullpath}".log "${out_dir}/ERROR_$(basename ${backup_fullpath})".log
else
    if [ "${skip_restore}" != "T" ]; then
        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] removing old ${db_alias}.fdb from ${out_dir}"
        rm -f "${out_dir}/${db_alias}".fdb

        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] starting restore for ${backup_fullpath} into ${restore_fullpath}"
        ${fb_gbak} -user ${db_user} -password ${db_password} -c -v ${parallel} "${backup_fullpath}" ${restore_with_replace} "${restore_fullpath}" -y "${restore_log_fullpath}"
        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] restore has been finished"

        if grep -e "${error_pattern}" "${restore_log_fullpath}"; then
            echo "[$(date +%Y-%m-%d\ %H:%M:%S)] ERROR during restore"

            if [[ -n ${notifier} ]] ; then
                    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] calling notifier ${notifier}"
                    ${notifier} "Database restore error: $(grep -e "${error_pattern}" "${restore_log_fullpath}")"
            fi

            echo "[$(date +%Y-%m-%d\ %H:%M:%S)] moving ${restore_log_fullpath} to ${out_dir}/ERROR_$(basename ${restore_log_fullpath}).log"
            mv "${restore_log_fullpath}" "${out_dir}/ERROR_$(basename ${restore_log_fullpath}).log"
        else
            echo "[$(date +%Y-%m-%d\ %H:%M:%S)] append size info to ${out_dir}/${db_alias}.sizelog"
            ls -lhs "${restore_fullpath}" >> "${out_dir}/${db_alias}".sizelog

            if [[ -z "${restore_with_replace}" ]]; then
                echo "[$(date +%Y-%m-%d\ %H:%M:%S)] force renaming ${restore_fullpath} to ${out_dir}/${db_alias}.fdb"
                mv -f "${restore_fullpath}" "${out_dir}/${db_alias}".fdb
            fi

            echo "[$(date +%Y-%m-%d\ %H:%M:%S)] force copying ${restore_log_fullpath} to ${out_dir}/${db_alias}.fdb.log"
            cp -f "${restore_log_fullpath}" "${out_dir}/${db_alias}".fdb.log
        fi
    else
        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] restore skipping because of -s option"
    fi

    if [ "${through_console}" != "T" ]; then
        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] making archive ${archive_name} for ${backup_fullpath}"
        ${zipper} a "${archive_name}" "${backup_fullpath}" "${backup_fullpath}".log
        if [ "${skip_restore}" != "T" ]; then
            ${zipper} a "${archive_name}" "${restore_log_fullpath}"
        fi
    else
        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] add ${backup_fullpath}.log into archive ${archive_name} "
        ${zipper} a "${archive_name}" "${backup_fullpath}".log
    fi

    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] force moving ${archive_name} to ${out_dir}/${archive_name}"
    mv -f "${archive_name}" "${out_dir}/${archive_name}"

    if [[ -n ${mover} ]] ; then
        echo "[$(date +%Y-%m-%d\ %H:%M:%S)] calling mover ${mover}"
        ${mover} "${out_dir}/${archive_name}"
    fi
fi

if [[ "$(pwd)" == "${work_dir}" ]]; then
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] clean ${work_dir}"
    rm ./*
fi

echo "[$(date +%Y-%m-%d\ %H:%M:%S)] restore working directory"
popd
