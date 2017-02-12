-- removes procedure (and its dependencies before)
create or alter procedure aux_drop_procedure(
    name varchar(31)
)
as
declare dependent_name varchar(31);
declare drop_names blob sub_type text;
declare pos bigint;
begin
    name = upper(name);
    
    drop_names = name;
    while (drop_names <> '') do
    begin
        pos = position(',' in drop_names);
        if (pos = 0) then pos = char_length(drop_names) + 1;
        name = left(drop_names, pos - 1);
        for select distinct trim(rdb$dependent_name)
            from rdb$dependencies 
            where rdb$depended_on_name = :name and rdb$dependent_name <> :name
            into dependent_name
            do drop_names = dependent_name 
                    || ',' || replace(drop_names, ',' || dependent_name || ',', ',');

        if (row_count = 0) then
        begin
            if (name <> upper('aux_drop_procedure')
                and exists(select * from rdb$procedures where rdb$procedure_name = :name)
                ) then execute statement 'drop procedure ' || :name;
            drop_names = substring(drop_names from pos + 1);
        end
    end
end