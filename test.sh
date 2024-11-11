#! /usr/bin/env bash

# author: atronah (look for me by this nickname on GitHub and GitLab)
# source: https://github.com/atronah/firebird_utils

scriptpath="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

verbose=false
db="test.fdb"
db_user="SYSDBA"
db_password='masterkey'

usage () {
    echo "usage: test.sh [arguments]"
    echo ""
    echo "arguments:"
    echo "-v                shows each test details"
    echo "-h                shows this help"
    echo "-d DATABASE       specify database file or connection string for tests (default '${db}')"
    echo "-u USERNAME       specify username to connect to test database (default '${db_user}')"
    echo "-p USERNAME       specify username to connect to test database (default '${db_password}')"
}


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
    test_results=$(${scriptpath}/tests/run_tests.sh "$db" "$db_user" "$db_password" | tee >(cat - >&8))
else
    test_results=$(${scriptpath}/tests/run_tests.sh "$db" "$db_user" "$db_password")
fi

read -p "Press any key to resume ..."