# Database objects changes monitoring tools

- **Version**: [1.1.0 from 2025-06-04](https://github.com/atronah/firebird_utils/releases/tag/dbmon_v1.1.0)

This solution allows you to track changes of database meta objects (structure changes) like procedures, triggers, tables, etc.
and changes in values of table fields (data changes).

<!-- MarkdownTOC autolink="true" lowercase="all" uri_encoding="false" -->

- [How it works](#how-it-works)
- [Install](#install)
    - [Manually install](#manually-install)
- [How to setup](#how-to-setup)
    - [Common settings](#common-settings)
        - [log_attachment_client_os_user](#log_attachment_client_os_user)
        - [log_attachment_client_version](#log_attachment_client_version)
        - [log_attachment_server_pid](#log_attachment_server_pid)
        - [log_attachment_auth_method](#log_attachment_auth_method)
        - [log_context_variables](#log_context_variables)
        - [log_call_stack](#log_call_stack)
        - [log_prev_unified_create_statement](#log_prev_unified_create_statement)
    - [Tracked fields](#tracked-fields)
- [Useful queries](#useful-queries)
    - [Add tracking for all tables](#add-tracking-for-all-tables)
    - [Perfomance reducing checking](#perfomance-reducing-checking)

<!-- /MarkdownTOC -->


## How it works

All database structure changes are detected by DDL-trigger [dbmon_before_any_ddl_statement][]
and saved into table [dbmon_structure_changelog][].

Data changes are detected by special dbmon-triggers on tables (which you decided to track)
and saved into table [dbmon_data_changelog][].
Required to track special dbmon-triggers are created automatically by procedure [dbmon_create_triggers][]
when you add new tracking rule into table [dbmon_tracked_field][] with value `1` in field `update_track_triggers = 1`
(or when you change value of field `update_track_triggers` to `1` for existed rule).


## Install

See all versions of `dbmon` on [Realease page](https://github.com/atronah/firebird_utils/releases/).

All version description includes archive (name should be like `dbmon_v#.#.#.7z`),
which should contain the following scripts:

- `00_dbmon_aux.sql` - to install or update auxiliary requirements,
which includes:
    - (required) procedure [aux_split_text][]
    - (optional) [aux_get_create_statement][]
- `01_dbmon_install.sql` - to initial install `dbmon`
(on database in which it was not previously installed)
- `02_dbmon_update.sql` - to update `dbmon`, installed before


### Manually install

To install that solution manually into your database you should:

- create or update (alter) required auxiliary dependecies
    - (required) procedure [aux_split_text][] - needs for dbmon triggers on changelog tables to process list of context variables from dbmon settings
    - (optional) procedure [aux_get_create_statement][] - needs to use feature [log_prev_unified_create_statement](#log_prev_unified_create_statement)
- create common objectcs
    - create table [dbmon_settings][] to store settings of that project
    - add supported settings into the table [dbmon_settings][] by executing script [mrg_dbmon_settings.sql][]
- to track database structure changes
    - create table [dbmon_structure_changelog][] to store journal of db structure changes
    - create trigger [dbmon_structure_changelog_bui][] to compute and fill metadata of logged changes
    - create DDL-trigger [dbmon_before_any_ddl_statement][] to detect and save changes in db structure
- to track database data changes
    - create table [dbmon_data_changelog][] to store journal of db data changes
    - create table [dbmon_tracked_field][] to store rules of tracking data changes (names of tables and fields to track with extra settings lile where conditions)
    - create procedure  [dbmon_create_triggers][] to creating dbmon special triggers on tracked tables which is detect changes
    - create trigger [dbmon_data_changelog_bui][] to compute and fill metadata of logged changes
    - create trigger [dbmon_tracked_field_aui][] to call [dbmon_create_triggers][] when value `1` put into field `update_track_triggers` of table [dbmon_tracked_field][]
    - create trigger [dbmon_tracked_field_bui][] - to replace null-values by default values

P.S.: if some tables already exist in database you can update its fields using scripts from [update_fields.sql][].


## How to setup

That solution has settings that provide you some customization.

There're few types of settings 

- [common settings](#common-settings), stored in table [dbmon_settings][]
- [tracked fields](#tracked-fields) for each tracked field 


### Common settings

#### log_attachment_client_os_user

If more than `0` 
info from `mon$attachments.mon$remote_os_user` will be saved to `client_os_user` field 
of tables [dbmon_structure_changelog][] and [dbmon_data_changelog][].


#### log_attachment_client_version

If more than `0` 
info from `mon$attachments.mon$client_version` will be saved to `client_version` field 
of tables [dbmon_structure_changelog][] and [dbmon_data_changelog][].


#### log_attachment_server_pid

If more than `0` 
info from `mon$attachments.mon$server_pid` will be saved to `server_pid` field 
of tables [dbmon_structure_changelog][] and [dbmon_data_changelog][].


#### log_attachment_auth_method

If more than `0` 
info from `mon$attachments.mon$auth_method` will be saved to `auth_method` field 
of tables [dbmon_structure_changelog][] and [dbmon_data_changelog][].


#### log_context_variables

Semicolon separated list of context variables (in format `<NAME_SPACE>.<VARIABLE_NAME>`) 
which should be logged into field `context_variables` 
of tables [dbmon_structure_changelog][] and [dbmon_data_changelog][].

If not exmpty, value will be splitted to a list of `<NAME_SPACE>.<VARIABLE_NAME>`
to store into field `context_variables` all values 
obtained by calling `rdb$get_context('<NAME_SPACE>', '<VARIABLE_NAME>')`.


#### log_call_stack

If more than `0` 
info from table `mon$call_stack` will be saved to `call_stack` field 
of tables [dbmon_structure_changelog][] and [dbmon_data_changelog][].


#### log_prev_unified_create_statement

If more than `0` 
create statement for previous version ob database object (before update) 
obtained by calling procedure [aux_get_create_statement][]
will be saved to field `prev_unified_create_statement`
of table [dbmon_structure_changelog][].



### Tracked fields

To start logging changing data in some fields of some table
you shoud add that fields into the table [dbmon_tracked_field][].

Table [dbmon_tracked_field][] has follow columns:

- `table_name` - name of table which field needs to be track for data changes
- `field_name` - name of field (or `*` for all fields of table) that need to be track for data changes
- `enabled` - if more than `0` data changes will be saved to [dbmon_data_changelog][], otherwise changes will be ignored
- `extra_cond` - condition which should be true to save data changes into [dbmon_data_changelog][], 
in format `coalesce(new.my_field, old.my_field) is not null and coalesce(new.my_field, old.my_field) < 123`
- `exclude_roles` - data changes from that role (pr few roles, separated by comma) will be ignored 
and not saved into table [dbmon_data_changelog][]
- `update_track_triggers` - if more than `0`, all required triggers will be (re)create for table from `table_name`
and that field will be resetted to `0`
- `log_call_stack` - if more than `0`, info from table `mon$call_stack` will be saved to `call_stack` field 
of [dbmon_data_changelog][] table


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

[aux_split_text]: /prc_aux_split_text.sql
[aux_get_create_statement]: /prc_aux_get_create_statement.sql

[dbmon_settings]: tbl_dbmon_settings.sql
[mrg_dbmon_settings.sql]: update_fields.sql

[dbmon_structure_changelog]: tbl_dbmon_structure_changelog.sql
[dbmon_structure_changelog_bui]: trg_dbmon_structure_changelog_bui.sql
[dbmon_before_any_ddl_statement]: trg_dbmon_before_any_ddl_statement.sql

[dbmon_data_changelog]: tbl_dbmon_data_changelog.sql
[dbmon_tracked_field]: tbl_dbmon_tracked_field.sql
[dbmon_create_triggers]: prc_dbmon_create_triggers.sql
[dbmon_data_changelog_bui]: trg_dbmon_data_changelog_bui.sql
[dbmon_tracked_field_aui]: trg_dbmon_tracked_field_aui.sql
[dbmon_tracked_field_bui]: trg_dbmon_tracked_field_bui.sql

[update_fields.sql]: update_fields.sql
