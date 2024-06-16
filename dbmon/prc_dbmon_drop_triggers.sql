set term ^ ;
create or alter procedure dbmon_drop_triggers(
    table_name_filter type of column dbmon_tracked_field.table_name = null
    , work_mode smallint = null
)
returns (
    table_name type of column dbmon_tracked_field.table_name
    , trigger_name type of column rdb$triggers.rdb$trigger_name
    , drop_trigger_statement tblob
)
as
declare TRIGGER_NAME_PREFIX varchar(32) = 'dbmon';
declare TRIGGER_NAME_SUFFIX varchar(32) = 'auid';
declare NAME_GEN_ATTEMPT_LIMIT bigint = 99;
begin
    table_name_filter = nullif(upper(trim(table_name_filter)), '');
    work_mode = coalesce(work_mode, 0);

    TRIGGER_NAME_PREFIX = upper(TRIGGER_NAME_PREFIX);
    TRIGGER_NAME_SUFFIX = upper(TRIGGER_NAME_SUFFIX);

    for select
            trim(rdb$relation_name), trim(rdb$trigger_name)
        from rdb$triggers
        where rdb$relation_name = coalesce(:table_name_filter, rdb$relation_name)
            and rdb$trigger_name starts with (:TRIGGER_NAME_PREFIX || '_')
            and right(trim(rdb$trigger_name), char_length(:TRIGGER_NAME_SUFFIX) + 1) = '_' || :TRIGGER_NAME_SUFFIX
        into table_name, trigger_name
    do
    begin
        drop_trigger_statement = 'drop trigger ' || trigger_name || ';';

        if (work_mode = 0)
            then suspend;
        else if (work_mode = 1)
            then execute statement drop_trigger_statement;
    end
end^

set term ; ^


comment on procedure dbmon_drop_triggers is 'Procedure to drop triggers for tracking changes';

comment on parameter dbmon_drop_triggers.table_name_filter is 'Optional table name filter for tables that a /the trigger is to be dropped for.
If not passed (passed `null`), all triggers with prefix `dbmon_` and `_auid` suffix will be dropped';
comment on parameter dbmon_drop_triggers.work_mode is 'Work mode: 0 (default) - suspend drop statements to manual execute; 1 - execute drop statements';
