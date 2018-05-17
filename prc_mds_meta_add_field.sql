set term ^ ;

-- adds field into table if it is not exists
create or alter procedure mds_meta_add_field(
    table_name varchar(31)
    , field_name varchar(31)
    , field_type varchar(31)
    , field_comment varchar(255) = null
    , field_position smallint = null
)
as
begin
    table_name = trim(table_name);
    field_name = trim(field_name);

    if (not exists(select rdb$field_name
                    from rdb$relation_fields
                    where trim(rdb$relation_name) = upper(:table_name)
                        and trim(rdb$field_name) = upper(:field_name)))
    then
    begin
        execute statement 'alter table ' || table_name
                            || ' add ' || field_name || ' ' || field_type
                            -- without it fails when execute from scrip file (by `isql -i`) after creating table
                            with autonomous transaction;
    end
    if (field_comment is not null)
        then execute statement 'comment on column ' || table_name || '.' || field_name
                                    || ' is ''' || field_comment || ''''
                                    with autonomous transaction;
    if (coalesce(field_position, 0) > 0) then
    begin
        execute statement 'alter table ' || table_name
                            || ' alter ' || field_name
                            || ' position ' || field_position
                            with autonomous transaction;
    end
end^

set term ; ^