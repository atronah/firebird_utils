select distinct
    trim(rf.rdb$relation_name)
    , list(trim(rf.rdb$field_name))
    ,  'or (trim(rf.rdb$relation_name) = ''' || trim(rf.rdb$relation_name) || ''' and trim(rf.rdb$field_name) in (' || list('''' || trim(rf.rdb$field_name) || '''') || '))'
from rdb$relation_fields as rf
    inner join rdb$relations as r on coalesce(r.rdb$relation_type, 0) = 0 -- The type of the relation object being described: 0 - system or user-defined table
                                        and r.rdb$relation_name = rf.rdb$relation_name
                                        and coalesce(r.rdb$system_flag, 0) = 0
where rf.rdb$field_name containing :field_name
group by 1