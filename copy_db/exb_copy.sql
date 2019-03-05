execute block
as
declare db_path varchar(255);
declare db_user varchar(32);
declare db_password varchar(32);

declare error_code bigint;
declare error_text varchar(1024);
declare total_records type of column copydb_tables_journal.total_records;
declare copied_records type of column copydb_tables_journal.copied_records;

declare table_id type of column copydb_tables_journal.id;
declare table_name type of column copydb_tables_journal.name;
-- constants
declare T_SUCCESS type of column copydb_tables_journal.status = 0;
declare T_INPROGRESS type of column copydb_tables_journal.status = 1;
declare T_ERROR type of column copydb_tables_journal.status = 2;
begin
    db_path = ;
    db_user = 'SYSDBA';
    db_password = 'masterkey';

    for select trim(rdb$relation_name) as obj_name
        from rdb$relations
        where coalesce(rdb$relation_type, 0) in (0, 4, 5) -- 0 - system or user-defined table; 4/5 - GTT (connection/transaction level)
            and coalesce(rdb$system_flag, 0) = 0 -- except system tables
            and trim(upper(rdb$relation_name)) <> upper('copydb_tables_journal') -- except copydb table
        into table_name
    do
    begin
        table_id = null;
        
        select id
            from copydb_tables_journal
            where upper(name) = upper(:table_name)
            into table_id;
        
        in autonomous transaction do
        begin
            if (table_id is null) then
            begin
                table_id = next value for copydb_tables_journal_seq;
                insert into copydb_tables_journal (id, name, processed, status) values (:table_id, :table_name, 'now', :T_INPROGRESS);

                select error_code, error_text, total_records, copied_records
                    from copydb_copy_table(:table_name, :db_path, :db_user, :db_password)
                    into error_code, error_text, total_records, copied_records;

                update copydb_tables_journal
                    set status = iif(:error_code = 0, :T_SUCCESS, :T_ERROR)
                        , processed = 'now'
                        , info = iif(:error_code = 0, info, :error_text)
                        , total_records = :total_records
                        , copied_records = :copied_records
                    where id = :table_id;
            end
        end
    end
end