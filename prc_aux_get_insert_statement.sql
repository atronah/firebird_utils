create or alter procedure aux_get_insert_statement(
    relation_name varchar(31)
    , where_part varchar(32000) = null
    , exclude_field_list varchar(32000) = null
    , rows_part varchar(255) = null
    , update_or_insert smallint = null
    , add_commit_every_n_row bigint = null
)
returns(
    row_number bigint
    , statement blob sub_type text
    , field_list varchar(32000)
    , field_count bigint
    , declare_list varchar(32000)
    , suspend_list varchar(32000)
    , get_values_statement blob sub_type text
)
as
declare processed_row bigint;
declare field_name varchar(31);
declare values_list blob sub_type text;
declare field ttext64;
begin
    exclude_field_list = coalesce(exclude_field_list, '');
    relation_name = trim(relation_name);
    where_part = coalesce(where_part, '1=1');
    update_or_insert = coalesce(update_or_insert, 0);
    add_commit_every_n_row = coalesce(add_commit_every_n_row, 0);

    field_list = '';
    declare_list = '';
    values_list = '';
    field_count = 0;
    for select trim(r.rdb$field_name)
        from rdb$relation_fields as r
        where r.rdb$relation_name = :relation_name
            and ',' || upper(:exclude_field_list) || ',' not like '%,' || trim(r.rdb$field_name) || ',%'
        order by r.rdb$field_position
        into field_name
    do
    begin
        field_list = field_list || ',' || field_name;
        field_count = field_count + 1;
        declare_list = declare_list || x'0d0a' || 'declare ' || field_name || ' type of column ' || relation_name || '.' || field_name || ';';
        values_list = values_list || ' || '','' || coalesce(''''''''|| ' || field_name || ' || '''''''', ''null'')';
    end
    field_list = trim(',' from field_list);

    if (field_list > '') then
    begin
        get_values_statement = 'execute block
                returns (
                    row_number bigint
                    , values_list blob sub_type text
                )
                as ' ||
                declare_list || '
                begin
                    values_list = '''';
                    for select
                                row_number() over (), ' || field_list || '
                        from ' || relation_name || '
                        where ' || where_part || '
                        ' || iif(rows_part is not null, 'rows ' || rows_part, '') || '
                        into row_number, ' || field_list || '
                    do
                    begin
                        values_list = ' || substring(values_list from position('coalesce' in values_list)) || ';
                        suspend;
                    end
                end';

        processed_row = 0;
        for execute statement get_values_statement
            into row_number, values_list
        do
        begin
            statement = 'insert into ' || relation_name || ' (' || field_list
                                || ') values (' || trim(',' from values_list) || ');';
            if (update_or_insert > 0)
                then statement = 'update or ' || statement;

            suspend;

            processed_row = processed_row + 1;
            if (add_commit_every_n_row > 0 and mod(processed_row, add_commit_every_n_row) = 0) then
            begin
                statement = 'commit;';
                suspend;
            end
        end
    end
end