execute block
as
declare name varchar(31);
declare relation_name varchar(31);
declare stmt blob sub_type text;
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    -- Заменяет все процедуры на ничего не делающие заглушки
    for select 'create or alter procedure '
            || trim(procs.rdb$procedure_name)
            || coalesce((select '(' || list(trim(rdb$parameter_name) || ' varchar(1) = null') || ')'
                            from rdb$procedure_parameters as params
                            where params.rdb$procedure_name = procs.rdb$procedure_name
                                and rdb$parameter_type = 0)
                        , '')
            || coalesce((select ' returns(' || list(trim(rdb$parameter_name) || ' varchar(1)') || ')'
                            from rdb$procedure_parameters as params
                            where params.rdb$procedure_name = procs.rdb$procedure_name
                                and rdb$parameter_type = 1)
                         , '')
            || ' as begin '
            || iif(rdb$procedure_source containing 'suspend'
                    and exists(select *
                                from rdb$procedure_parameters as params
                                where params.rdb$procedure_name = procs.rdb$procedure_name
                                    and rdb$parameter_type = 1)
                    , ' suspend; '
                    , '')
            || 'end'
        from rdb$procedures as procs
        where procs.rdb$system_flag = 0
        into stmt
        do execute statement stmt ;

    -- Подготавливает шаблон запроса для выполнения без падения из-за ошибок
    stmt = 'execute block
            as
            begin
                execute statement ''{statement}'';
                when any do begin end
            end';

    -- Удаляет все триггеры
    for select trim(rdb$trigger_name) from rdb$triggers where rdb$system_flag = 0 into name
        do execute statement replace(stmt, '{statement}', 'drop trigger ' || :name);
    -- удаляет все ограничения (constraint)
    for select
            trim(rdb$constraint_name),
            trim(rdb$relation_name)
        from rdb$relation_constraints
        order by iif(rdb$constraint_type containing 'not null', 1, 0)
        into name, relation_name
        do execute statement replace(stmt, '{statement}', 'alter table ' || :relation_name || ' drop constraint ' || :name);
    -- удаляет все индексы
    for select distinct
                trim(rdb$index_name)
            from rdb$indices
            where rdb$system_flag = 0
                and not exists (select * from rdb$dependencies where rdb$depended_on_name = rdb$index_name)
            into name
        do execute statement replace(stmt, '{statement}', 'drop index ' || :name);
    -- удаляет все привелении всех пользователей
    delete from rdb$user_privileges;
end
