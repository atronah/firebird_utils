#!/usr/bin/env bash

# author: atronah (look for me by this nickname on GitHub and GitLab)
# source: https://github.com/atronah/firebird_utils

gbak_util=/opt/firebird/bin/gbak
db_user=SYSDBA
db_pas=masterkey

db_alias=$1


if [ -z "$db_alias" ]; then
    db_alias=box_med
fi

backup_name="${db_alias}_$(date +%Y-%m-%d_%H%M%S)"

echo "started backup '${db_alias}' into archive '${backup_name}.fbk.7z' with logging into '${backup_name}.fbk.log'"
"${gbak_util}" -user ${db_user} -pas ${db_pas} -b -g -v ${db_alias} stdout -y ${backup_name}.fbk.log | 7za a -si ${backup_name}.fbk.7z

echo "archiving '${backup_name}.fbk.log' into '${backup_name}.fbk.7z'"
7za a ${backup_name}.fbk.7z ${backup_name}.fbk.log

echo "done"
