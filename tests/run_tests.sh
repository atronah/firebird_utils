#! /usr/bin/env bash

db_name=$1
db_user=$2
db_password=$3

scriptpath="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# redirect out into 8th file descriptor to stdout
# to out both into in stdout and into variable
# source https://stackoverflow.com/a/12451419
exec 8>&1

pushd ${scriptpath}

check_result () {
    if [[ ! $1 =~ "ALL TESTS PASSED" ]]; then
        echo "$test_result" >&2
    fi
}

rm -f ${db_name}
echo 'create test database'
echo "create database '${db_name}' page_size 16384; commit;" | isql -user ${db_user} -pas ${db_password} -q

echo 'initiating test database'
# isql -user ${db_user} -pas ${db_password} ${db_name} -i ./tests/init_test_db.sql

echo 'testing procedure aux_strip_text'
isql -user ${db_user} -pas ${db_password} ${db_name} -i ../prc_aux_strip_text.sql
test_result=$(isql -user ${db_user} -pas ${db_password} ${db_name} -i ./test_aux_strip_text.sql | tee >(cat - >&8))
check_result "$test_result"

rm -f ${db_name}

popd