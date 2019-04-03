select 
    trim(idx.rdb$index_name) as index_name
    , trim(rc.rdb$relation_name) as table_name
    , trim(idxs.rdb$field_name) as field_name
    , decode(rdb$field_type
            , 7, 'smallint'
            , 8, 'integer'
            , 10, 'float'
            , 12, 'date'
            , 13, 'time'
            , 14, 'char'
            , 16, 'bigint'
            , 27, 'double precision'
            , 35, 'timestamp'
            , 37, 'varchar'
            , 261, 'blob'
    ) as field_type
from rdb$relation_constraints as rc
    inner join rdb$indices as idx on idx.rdb$index_name = rc.rdb$index_name
    inner join rdb$index_segments as idxs on idxs.rdb$index_name = idx.rdb$index_name
    inner join rdb$relation_fields as rf on rf.rdb$relation_name = rc.rdb$relation_name 
                                                and rf.rdb$field_name = idxs.rdb$field_name
    inner join rdb$fields as f on f.rdb$field_name = rdb$field_source
where rdb$constraint_type = 'PRIMARY KEY'

