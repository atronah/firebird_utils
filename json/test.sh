#! /usr/bin/env bash

db_user=SYSDBA
db_password=masterkey
db_name=test.fdb

rm -f test.fdb
echo "create database '${db_name}' page_size 16384; commit;" | isql -user ${db_user} -pas ${db_password}

isql -user ${db_user} -pas ${db_password} ${db_name} -i prc_aux_json_parse.sql
isql -user ${db_user} -pas ${db_password} ${db_name} -i exb_test_aux_json_parse.sql

isql -user ${db_user} -pas ${db_password} ${db_name} -i prc_aux_json_get_node.sql
isql -user ${db_user} -pas ${db_password} ${db_name} -i exb_test_aux_json_get_node.sql

rm -f test.fdb