#! /usr/bin/env bash

db_user=SYSDBA
db_password=masterkey
db_name=test.fdb

usage () {
    echo "usage: test.sh [arguments]"
    echo ""
    echo "arguments:"
    echo "-v                shows each test details"
    echo "-h                shows this help"
    echo "-d DATABASE     specify database file or connection string for tests (default 'test.fdb')"
    echo "-u USERNAME     specify username to connect to test database (default 'SYSDBA')"
    echo "-p USERNAME     specify username to connect to test database (default 'masterkey')"
}

verbose=false
db="test.fdb"
db_user="SYSDBA"
db_password='masterkey'

# Parse arguments
while getopts "v,h,:d:,u:,p:" opt; do
    case $opt in
        v) verbose=true
        ;;
        h) usage && exit 0
        ;;
        d) db="$OPTARG"
        ;;
        u) db_user="$OPTARG"
        ;;
        p) db_password="$OPTARG"
        ;;
        *) echo "Invalid option or its argument: $OPTARG" >&2
            usage && exit 1
        ;;
    esac
done

if [ $verbose = true ]; then
    exec 8>&1
    test_results=$(./tests/run_tests.sh "$db" "$db_user" "$db_password" | tee >(cat - >&8))
else
    test_results=$(./tests/run_tests.sh "$db" "$db_user" "$db_password")
fi