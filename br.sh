#!/usr/bin/env bash

db_user=SYSDBA
db_pswd=masterkey
db_path=$1
out_dir=$2
name_suffix=$3
shift 3
extra_opt=$*


if [[ ! -f $db_path ]]; then
    echo database \"$1\" does not exists
    exit 1
fi

if [[ ! -d $out_dir ]]; then
    echo out dir \"$1\" does not exists
    exit 1
fi

out_name="${out_dir}/$(basename ${db_path} .fdb)_$(date +%Y-%m-%d_%H%M%S)${name_suffix}"

echo "started at $(date) for ${out_name}"
gbak -b -g -v -user ${db_user} -pas ${db_pswd} -y "${out_name}.fbk.log" ${extra_opt} "${db_path}" stdout | gbak -c -v -user ${db_user} -pas ${db_pswd} -y "${out_name}.fdb.log" ${extra_opt} stdin "${out_name}.fdb"


# echo "update my_tabke set field1=null,field1=null; commit;" | isql -user ${db_user} -pas ${db_pswd} "${out_name}.fdb"
