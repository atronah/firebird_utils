create sequence copydb_tables_journal_seq;

create table copydb_tables_journal (
    id bigint
    , name varchar(31)
    , total_records bigint
    , copied_records bigint
    , skipped_records bigint
    , status smallint
    , processed timestamp
    , info varchar(1024)
    , constraint pk_copydb_tables_journal primary key (id)
);

create unique index copydb_tables_journal_name on copydb_tables_journal computed by (upper(name));

comment on column copydb_tables_journal.status is '0 - Успешно скопировано; 1 - В процессе копирования; 99 - Ошибка в процессе копирования';