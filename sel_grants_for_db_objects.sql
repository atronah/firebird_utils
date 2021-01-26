with obj as (
    select 'procedure' as type_name, rdb$procedure_name as name
    from rdb$procedures
    where coalesce(rdb$system_flag, 0) = 0
    union all
    select
        decode(rdb$relation_type
                , 1, 'view'
                , 'table'
        ) as type_name
        , rdb$relation_name as name
    from rdb$relations
    where coalesce(rdb$system_flag, 0) = 0
        and rdb$relation_type in (0 -- 0 - system or user-defined table
                                    , 1 -- 1 - view
                                    , 4 -- 4 - connection-level GTT (PRESERVE ROWS)
                                    , 5 -- 5 - transaction-level GTT
                                )
)
select
    u.sec$user_name as user_name
    , obj.type_name, obj.name
    , '[' || trim(up.rdb$privilege) || '] '
        || decode(up.rdb$privilege
                    , 'S', 'SELECT'
                    , 'D', 'DELETE'
                    , 'I', 'INSERT'
                    , 'U', 'UPDATE'
                    , 'R', 'REFERENCE'
                    , 'T', 'DECRYPT'
                    , 'E', 'ENCRYPT'
                    , 'B', 'SUBSCRIBE'
                    , 'X', 'EXECUTE'
                    , 'Z', 'TRUNCATE'
                    , 'M', 'MEMBER OF (for roles)'
                    , '?'
    ) as privilege
    , up.rdb$grant_option as is_with_grant_option
    , replace(replace(s.part, '<obj>', trim(obj.name)), '<user>', trim(u.sec$user_name)) as stmt
from sec$users as u
    inner join obj on 1 = 1
    left join aux_split_text('GRANT SELECT ON <obj> TO USER <user>;'
                            || '/' || 'GRANT INSERT ON <obj> TO USER <user>;'
                            || '/' || 'GRANT UPDATE ON <obj> TO USER <user>;'
                            || '/' || 'GRANT EXECUTE PROCEDURE <obj> TO USER <user>;'
                            , '/'
                            ) as s on ((obj.type_name in ('table', 'view') and part containing 'SELECT')
                                    or (obj.type_name in ('table') and part containing 'INSERT')
                                    or (obj.type_name in ('table') and part containing 'UPDATE')
                                    or (obj.type_name in ('procedure') and part containing 'EXECUTE PROCEDURE'))
    left join rdb$user_privileges as up on up.rdb$user = u.sec$user_name
                                            and up.rdb$relation_name = obj.name
                                            and up.rdb$privilege = case
                                                                        when s.part containing 'GRANT SELECT' then 'S'
                                                                        when s.part containing 'GRANT INSERT' then 'I'
                                                                        when s.part containing 'GRANT UPDATE' then 'U'
                                                                        when s.part containing 'GRANT EXECUTE PROCEDURE' then 'X'
                                                                    end
where u.sec$user_name = :USER_NAME
    and up.rdb$privilege is null