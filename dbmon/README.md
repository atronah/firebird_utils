# Database objects changes monitoring tools

This solution allows you to track changes in database meta objects (procedures, triggers, tables)
and int the data (fields values in tables).

<!-- MarkdownTOC autolink="true" lowercase="all" uri_encoding="false" -->

- [How it works](#how-it-works)
- [Setup](#setup)
- [Using](#using)
- [Useful queries](#useful-queries)
    - [Add tracking for all tables](#add-tracking-for-all-tables)
    - [Perfomance reducing checking](#perfomance-reducing-checking)

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

- Create bash/batch script to run regulary checking for changes (in batch for windows remove double quotes `"`).
    ```cmd
    echo "execute procedure dbmon_check_for_changes('127.0.0.1:db_to_check', 'SYSDBA', 'masterkey');" | isql -user SYSDBA C:\DB\DBMON.FDB
    ```
- Add that script to scheduler (for example, into `crontab` for unix)
- Done


[DBMON_CHANGES_HISTORY]: tbl_dbmon_changes_history.sql
[DBMON_CHECK_FOR_CHANGES]: prc_dbmon_check_for_changes.sql
[DBMON_CHANGES_SUMMARY]: view_dbmon_changes_summary.sql
[AUX_GET_CREATE_STATEMENT]: ../prc_aux_get_create_statement.sql


## Useful queries

### Add tracking for all tables

```sql
merge into dbmon_tracked_field as cur
    using (
        select
            trim(t.rdb$relation_name) as table_name
            -- , trim(f.rdb$field_name) as field_name
            , '*' as field_name -- all fields
            , 1 as enabled -- enables tracking
            , null as extra_cond
            , null as exclude_roles
            , 1 as update_track_triggers -- create track triggers on table just after insert record
            , 1 as log_call_stack -- enables logging extra information: call stack from MON$CALL_STACK
            , 1 as log_context_variables -- enables logging extra information: context variables from MON$CONTEXT_VARIABLES
        from rdb$relations as t
            -- inner join rdb$relation_fields as f using(rdb$relation_name)
        where coalesce(t.rdb$system_flag, 0) = 0
            and coalesce(t.rdb$relation_type, 0) = 0
    ) as upd
    on cur.table_name = upd.table_name
        and cur.field_name = upd.field_name
    when not matched then insert
                (table_name, field_name, enabled
                , extra_cond, exclude_roles
                , update_track_triggers
                , log_call_stack, log_context_variables)
        values (upd.table_name, upd.field_name, upd.enabled
                , upd.extra_cond, upd.exclude_roles
                , upd.update_track_triggers
                , upd.log_call_stack, upd.log_context_variables)
    ;
```

### Perfomance reducing checking

```sql
execute block
returns (
    started timestamp
    , finished timestamp
    , duration_in_milliseconds bigint
    , tables_count bigint
    , fields_count bigint
)
as
declare field_type type of column rdb$fields.rdb$field_type;
declare field_length type of column rdb$fields.rdb$field_length;
declare update_statement varchar(1024);
declare prev_table_name type of column dbmon_tracked_field.table_name;
begin
    started = cast('now' as timestamp);
    tables_count = 0;
    fields_count = 0;
    for select distinct
            tf.table_name, tf.field_name
            , finfo.rdb$field_type
            , finfo.rdb$field_length
            , trim(iif(f.rdb$field_source starts with upper('RDB$')
                        , decode(finfo.rdb$field_type
                                , )
                            || iif(info.rdb$field_type in (14, 37) -- char/varchar
                                    , '(' || finfo.rdb$field_length || ')'
                                    , ''
                            )
                        , f.rdb$field_source)
            ) as field_type
        from dbmon_tracked_field as tf
            inner join rdb$relation_fields as f on f.rdb$relation_name = tf.table_name
                                                and f.rdb$field_name = tf.field_name
            inner join rdb$fields as finfo on finfo.rdb$field_name = f.rdb$field_source
        where tf.enabled = 1
        order by tf.table_name
        into table_name, field_name, field_type
    do
    begin
        update_statement = 'update ' || table_name || ' as t'
                            || ' set t.' || field_name
                                || ' = '
                                --

                                || case
                                        -- 7    - smallint
                                        -- 8    - integer
                                        -- 10   - float
                                        -- 16   - bigint
                                        -- 27   - doubleprecision
                                        when field_type in (7, 8, 10, 16, 27)
                                            then '-t.' || field_name
                                        -- 12   - date
                                        -- 35   - timestamp
                                        when field_type in (12, 35)
                                            then 'dateadd(1 day to t.' || field_name || ')'
                                        -- 13   - time
                                        when field_type in (13)
                                            then 'dateadd(1 minute to t.' || field_name || ')'
                                        -- 14   - char
                                        -- 37   - varchar
                                        when field_type in (14, 37)
                                            then 'left(123 || t.' || field_name || ','  || field_length || ')'
                                        -- 261  - blob
                                        when field_type in (261)
                                            then '123 || t.' || field_name
                                        -- 23   - boolean
                                        when field_type in (23)
                                            then 'not t.' || field_name
                                        else null
                                    end
                                || ';';

        if (table_name is distinct from prev_table_name) then
        begin
            tables_count = tables_count + 1;
            fields_count = 0;
        end
        fields_count = fields_count + 1;

        prev_table_name = table_name;
    end
    finished = cast('now' as timestamp);
    duration_in_milliseconds = datediff(millisecond from started to finished);
    suspend;

end
```

