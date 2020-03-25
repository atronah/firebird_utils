select
    r.rdb$relation_name
from rdb$relations as r
    left join rdb$indices as i on i.rdb$relation_name = r.rdb$relation_name
                                  and coalesce(i.rdb$unique_flag, 0) = 1
    left join rdb$relation_constraints as rc on rc.rdb$relation_name = r.rdb$relation_name
                                                and rc.rdb$constraint_type = 'PRIMARY KEY'
where coalesce(r.rdb$system_flag, 0) = 0
    and rc.rdb$constraint_name is null
    and i.rdb$index_name is null
    and coalesce(r.rdb$relation_type, 0) = 0
order by 1
