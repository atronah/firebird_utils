#! /usr/bin/env bash

db_user=SYSDBA
db_password=masterkey
db_name=test.fdb

scriptpath="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

pushd ${scriptpath}

rm -f ${db_name}
echo 'create test database'
echo "create database '${db_name}' page_size 16384; commit;" | isql -user ${db_user} -pas ${db_password}

echo 'init test database'
# isql -user ${db_user} -pas ${db_password} ${db_name} -i ./tests/init_test_db.sql

# echo 'tests procedure aux_strip_text'
# isql -user ${db_user} -pas ${db_password} ${db_name} -i prc_aux_strip_text.sql
# isql -user ${db_user} -pas ${db_password} ${db_name} -i ./tests/test_aux_strip_text.sql

rm -f ${db_name}

popd