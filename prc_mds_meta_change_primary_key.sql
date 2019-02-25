set term ^ ;

-- change primary key for table
create or alter procedure mds_meta_change_primary_key(
    table_name varchar(31)
    , fields_list varchar(1024)
    , constraint_name varchar(31) = null
    , no_change_constraint_name smallint = 1 -- if more than 0 do nothing for primary key which differs only by name
)
as
declare index_name varchar(31);
declare existed_constraint_name varchar(31);
declare existed_fields_list varchar(1024);
declare field_name varchar(31);
declare fb_engine_ver varchar(128);
begin
    table_name = trim(table_name);
    constraint_name = trim(coalesce(constraint_name, left('pk_' || table_name, 31)));
    select list(part) from aux_split_text(:fields_list, ',', 1) into fields_list;
    if (coalesce(fields_list, '') = '') then exit;

    -- get info about existing primary key
    select trim(cons.rdb$constraint_name)
            , list(trim(seg.rdb$field_name)) as current_fields_list
        from rdb$relation_constraints as cons
            inner join rdb$index_segments as seg on seg.rdb$index_name = cons.rdb$index_name
        where trim(upper(cons.rdb$relation_name)) = upper(:table_name)
            and trim(upper(cons.rdb$constraint_type)) = upper('primary key')
        group by 1
        into existed_constraint_name, existed_fields_list;

    -- (re)create primary key constraint if new constraint is different (by fields or name)
    if (upper(fields_list) is distinct from upper(existed_fields_list)
        or (upper(constraint_name) is distinct from upper(existed_constraint_name) and no_change_constraint_name = 0)
    ) then
    begin
        -- remove existed constraint
        if (coalesce(existed_constraint_name, '') <> '')
            then execute statement 'alter table ' || table_name || ' drop constraint ' || existed_constraint_name;

        -- set NOT NULL for fields which doesn't have it yet
        for select part
            from aux_split_text(:fields_list, ',', 1) as ast
                inner join rdb$relation_fields as rf on trim(upper(rf.rdb$relation_name)) = upper(:table_name)
                                                        and trim(upper(rf.rdb$field_name)) = upper(trim(ast.part))
            where coalesce(rdb$null_flag, 0) <> 1
            into field_name
        do 
        begin
            fb_engine_ver = coalesce(fb_engine_ver, (select rdb$get_context('SYSTEM', 'ENGINE_VERSION') from rdb$database));
            if (left(fb_engine_ver, 1) <= 2) 
                then execute statement 'update rdb$relation_fields set rdb$null_flag = 1 where rdb$field_name = upper(''' || field_name || ''') and rdb$relation_name = upper(''' || table_name || ''')';
            else execute statement 'alter table ' || table_name || ' alter ' || field_name || ' set not null';
                
        end

        execute statement 'alter table ' || table_name
                            || ' add constraint ' || constraint_name
                            || ' primary key (' || :fields_list ||  ')';
    end
end^

set term ; ^