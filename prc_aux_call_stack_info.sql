set term ^ ;

create or alter function aux_statement_call_stack(
    mon$statement_id type of column mon$statements.mon$statement_id
    , stmt_prefix varchar(64) = null
    , stmt_length bigint = null
    , depth_limit bigint = null
)
returns varchar(4096)
as
declare function frmt (
            object_name type of column mon$call_stack.mon$object_name
            , source_line type of column mon$call_stack.mon$source_line
            , source_column type of column mon$call_stack.mon$source_column
            , caller_id type of column mon$call_stack.mon$caller_id
        )
        returns varchar(1024)
        as
        begin
            return coalesce(trim(object_name), '?')
                              || '[' || coalesce(source_line, '?') || ':' || coalesce(source_column, '?') || ']'
                              || trim(coalesce('<' || caller_id, ''));
        end
declare depth bigint;
declare statement_id type of column mon$statements.mon$statement_id;
declare sql_text type of column mon$statements.mon$sql_text;
declare call_id type of column mon$call_stack.mon$call_id;
declare caller_id type of column mon$call_stack.mon$caller_id;
declare object_name type of column mon$call_stack.mon$object_name;
declare source_line type of column mon$call_stack.mon$source_line;
declare source_column type of column mon$call_stack.mon$source_column;
declare call_id_list varchar(1024);
declare call_info varchar(4096);
begin
    stmt_prefix = trim(coalesce(stmt_prefix, 'stmt:'));
    stmt_length = coalesce(stmt_length, 64);
    depth_limit = coalesce(depth_limit, 16);

    call_info = '';
    call_id_list = '';

    sql_text = (select left(mon$sql_text, :stmt_length) from mon$statements as s where s.mon$statement_id = :mon$statement_id);
    sql_text = replace(replace(sql_text, ascii_char(10), ''), ascii_char(13), '');
    call_info = left(call_info || stmt_prefix || coalesce(sql_text, 'null') || ascii_char(10), 4096);

    for select cs.mon$call_id, cs.mon$caller_id, cs.mon$object_name, cs.mon$source_line, cs.mon$source_column
        from mon$call_stack as cs
        where cs.mon$statement_id = :mon$statement_id
        into call_id, caller_id, object_name, source_line, source_column
    do
    begin
        call_info = left(call_info || '  ' || call_id || ':' || frmt(object_name, source_line, source_column, caller_id) || ascii_char(10), 4096);
        call_id_list = call_id_list || ',' || call_id;

        while (caller_id is not null and ',' || call_id_list || ',' not like '%,' || caller_id || ',%' and depth < depth_limit) do
        begin
            call_id_list = call_id_list || ',' || caller_id;

            call_id = null; caller_id = null; object_name = null; source_line = null; source_column = null;
            select cs.mon$call_id, cs.mon$caller_id, cs.mon$object_name, cs.mon$source_line, cs.mon$source_column
                from mon$call_stack as cs
                where cs.mon$call_id = :caller_id
                into call_id, caller_id, object_name, source_line, source_column;

            call_info = left(call_info || '  ' || call_id || ':' || frmt(object_name, source_line, source_column, caller_id) || ascii_char(10), 4096);
            depth = depth + 1;
        end
    end

    return call_info;
end^

set term ; ^