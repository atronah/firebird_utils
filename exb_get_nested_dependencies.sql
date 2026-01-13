-- Returns nested dependencies for objects which have specified `prefix` in name
execute block
returns(
    tables blob sub_type text
    , views blob sub_type text
    , triggers blob sub_type text
    , procedures blob sub_type text
    , exceptions blob sub_type text
    , columns blob sub_type text
    , sequences blob sub_type text
    , loop_number smallint
)
as
declare stmt blob sub_type text;
declare cond blob sub_type text;
declare obj_list blob sub_type text;
declare new_procedures blob sub_type text;
declare type_name varchar(31);
declare name_prefix varchar(31);
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    name_prefix = 'MDS_';

    select list('''' || trim(rdb$relation_name) || '''' || ascii_char(13) || ascii_char(10))
        from rdb$relations
        where coalesce(rdb$relation_type, 0) = 0 -- 0 - system or user-defined table
            and trim(rdb$relation_name) starts with :name_prefix
        into tables;
    select list('''' || trim(rdb$relation_name) || '''' || ascii_char(13) || ascii_char(10))
        from rdb$relations
        where rdb$relation_type = 1 -- 1 - view
            and trim(rdb$relation_name) starts with :name_prefix
        into views;
    select list('''' || trim(rdb$trigger_name) || '''' || ascii_char(13) || ascii_char(10))
        from rdb$triggers
        where trim(rdb$trigger_name) starts with :name_prefix
        into triggers;
    select list('''' || trim(rdb$procedure_name) || '''' || ascii_char(13) || ascii_char(10))
        from rdb$procedures
        where trim(rdb$procedure_name) starts with :name_prefix
        into procedures;

    exceptions = null;
    columns = null;
    sequences = null;

    stmt = 'select
            trim(decode(rdb$depended_on_type
                        , 0, ''table''
                        , 1, ''view''
                        , 2, ''trigger''
                        , 3, ''computed column''
                        , 4, ''constraint''
                        , 5, ''procedure''
                        , 6, ''index''
                        , 7, ''exception''
                        , 8, ''user''
                        , 9, ''column''
                        , 10, ''index''
                        , 14, ''sequence''
                        , 15, ''UDF''
                        , 17, ''collation''
                        , null
            )) as type_name
            , list(distinct '''''''' || trim(rdb$depended_on_name) || ''''''''
                    || ASCII_CHAR(13) || ASCII_CHAR(10)) as obj_list
        from rdb$dependencies
        where rdb$dependent_name --!--cond--!--
        group by 1';

    cond = 'starts with ''' || :name_prefix || '''';

    loop_number = 0;
    while (cond is not null and loop_number < 32) do
    begin
        loop_number = loop_number + 1;
        new_procedures = '';
        for execute statement replace(stmt, '--!--cond--!--', cond)
            into type_name, obj_list
        do
        begin
            if (type_name = 'table') then tables = coalesce(tables || ',', '') || obj_list;
            else if (type_name = 'view') then views = coalesce(views || ',', '') || obj_list;
            else if (type_name = 'trigger') then triggers = coalesce(triggers || ',', '') || obj_list;
            else if (type_name = 'procedure') then new_procedures = obj_list;
            else if (type_name = 'exception') then exceptions = coalesce(exceptions || ',', '') || obj_list;
            else if (type_name = 'column') then columns = coalesce(columns || ',', '') || obj_list;
            else if (type_name = 'sequence') then sequences = coalesce(sequences || ',', '') || obj_list;
        end

        if (coalesce(new_procedures, '') > '') then
        begin
            cond = 'in (' || new_procedures || ')'
                    || trim(coalesce(' and trim(rdb$depended_on_name) not in (' || tables || ')', ''))
                    || trim(coalesce(' and trim(rdb$depended_on_name) not in (' || views || ')', ''))
                    || trim(coalesce(' and trim(rdb$depended_on_name) not in (' || triggers || ')', ''))
                    || trim(coalesce(' and trim(rdb$depended_on_name) not in (' || procedures || ')', ''))
                    || trim(coalesce(' and trim(rdb$depended_on_name) not in (' || exceptions || ')', ''))
                    || trim(coalesce(' and trim(rdb$depended_on_name) not in (' || columns|| ')', ''))
                    || trim(coalesce(' and trim(rdb$depended_on_name) not in (' || sequences || ')', ''))
                    ;
            procedures = coalesce(procedures || ',', '') || new_procedures;
        end
        else cond = null;
    end
    suspend;
end
