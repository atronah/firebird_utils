set term ^ ;

create or alter procedure mds_meta_upd_index(
    index_name varchar(32)
    , index_table varchar(32)
    , index_expr varchar(4096)
    , index_unique smallint = null
    , index_desc smallint = null
)
as
declare stmt blob sub_type text;
declare isComputed smallint;
begin
    isComputed = 0;
    -- if index doesn't exist
    if (not exists(select *
                    from rdb$indices
                    where rdb$relation_name = upper(:index_table)
                                and rdb$index_name = upper(:index_name))) then
    begin
        -- if index_expr is not similar to field name pattern
        if (replace(:index_expr, ' ', '') not similar to '[a-zA-Z][a-zA-Z0-9_]*(,[a-zA-Z][a-zA-Z0-9_]*)*'
            -- or index_expr contains unknown table fields in passed index_expr (parsed as a comma-separated list )
            or exists(select *
                        from aux_split_text(:index_expr, ',') as i
                        where not exists(select *
                                            from rdb$relation_fields as f
                                            where trim(f.rdb$field_name) = upper(trim(i.part))
                                                    and rdb$relation_name = upper(:index_table)
                                        )
                   )) then -- add 'computed by' block
        begin
            isComputed = 1;
        end

        stmt = 'create'
                || iif(coalesce(index_unique, 0) = 1 and isComputed = 0, ' unique', '')
                || iif(isComputed = 0
                        , decode(coalesce(index_desc, -1)
                                , -1, ''
                                , 0, ' asc'
                                , 1, ' desc'
                                , '')
                        , '')
                || ' index ' || :index_name
                || ' on ' || :index_table;


        if (isComputed = 1) then stmt = stmt || ' computed by ';

        stmt = stmt || ' (' || :index_expr || ');';

        execute statement stmt with autonomous transaction;
    end
end^

set term ; ^

comment on procedure mds_meta_upd_index is 'Add new index if it doesn''t exist';

comment on parameter mds_meta_upd_index.index_name is 'Name for new index';
comment on parameter mds_meta_upd_index.index_table is 'Name of related Table for new index';
comment on parameter mds_meta_upd_index.index_expr is 'Field name or field name list or expression for new index';
comment on parameter mds_meta_upd_index.index_unique is 'Create unique index if this param equal 1 else create non-unique index';
comment on parameter mds_meta_upd_index.index_desc is 'Create ascending index if this param equal 0 else create non-unique index';
