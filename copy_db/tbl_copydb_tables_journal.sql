create sequence copydb_tables_journal_seq;

create table copydb_tables_journal (
    id bigint
    , table_name varchar(31)
    , total_records bigint
    , copied_records bigint
    , skipped_records bigint
    , status smallint
    , processed timestamp
    , info varchar(1024)
    , constraint pk_copydb_tables_journal primary key (id);
);

create unique index copydb_tables_journal_table_name on copydb_tables_journal(table_name);

comment on column copydb_log.status is '0 - Успешно скопировано; 1 - В процессе копирования; 99 - Ошибка в процессе копирования';