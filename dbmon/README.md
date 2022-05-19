# Database objects changes monitoring tools

This solution allows you to keep the change history of database objects (procedures, triggers, tables)
in another separate database.

<!-- MarkdownTOC autolink="true" lowercase="all" uri_encoding="false" -->

- [How it works](#how-it-works)
- [Setup](#setup)
- [Using](#using)

<!-- /MarkdownTOC -->


## How it works

You create special database (commonly called `DBMON`) to storing history of changes,
which contains:

- table [DBMON_CHANGES_HISTORY][] for stroing changes
- procedure [DBMON_CHECK_FOR_CHANGES][] to check changes in specified database
(information about database for check passed into procedure parameters)
- view [DBMON_CHANGES_SUMMARY][] to display the change history in convenient view
and periodicaly run procedure in that procedure

After that you run procedure [DBMON_CHECK_FOR_CHANGES][] in `DBMON`
with specifying access parameters to checked database.
That procedure compares current create statement (made by [AUX_GET_CREATE_STATEMENT][])
for each object in checked database with last stored in `DBMON` create statement of the same object
and if has differents it storing new version into [DBMON_CHANGES_HISTORY][]

You can also choose not to use a separate database (`DBMON`) for storing history of changes in monitored database,
instead you can create required objects directly in monitored database and run [DBMON_CHECK_FOR_CHANGES][] in it.


## Setup

- Create new database `DBMON` to store the change history, for example by follow command (for Windows cmd.exe):
    ```cmd
    echo create database 'C:\DB\DBMON.FDB' page_size 16384 default character set win1251; commit; | isql -user SYSDBA
    ```
- Init `DBMON` (create structure) by creating required objects:
    - [DBMON_CHANGES_HISTORY][] - table for storing the history of changes
    (for example by command: `isql -user SYSDBA C:\DB\DBMON.FDB -ch utf8 -i tbl_dbmon_changes_history.sql`)
    - [DBMON_CHECK_FOR_CHANGES][] - procedure to run process of checking target db for changes
    and store its into [DBMON_CHANGES_HISTORY][] table
    - [DBMON_CHANGES_SUMMARY][] - view to see the change history in convenient view
- Add procedure [AUX_GET_CREATE_STATEMENT][] into target database which you want to check for changes


## Using

- Create bash/batch script to run regulary checking for changes.
    ```cmd
    echo "execute procedure dbmon_check_for_changes('127.0.0.1:db_to_check', 'SYSDBA', 'masterkey');" | isql -user SYSDBA C:\DB\DBMON.FDB
    ```
- Add that script to scheduler (for example, into `crontab` for unix)
- Done


[DBMON_CHANGES_HISTORY]: tbl_dbmon_changes_history.sql
[DBMON_CHECK_FOR_CHANGES]: prc_dbmon_check_for_changes.sql
[DBMON_CHANGES_SUMMARY]: view_dbmon_changes_summary.sql
[AUX_GET_CREATE_STATEMENT]: ../prc_aux_get_create_statement.sql
