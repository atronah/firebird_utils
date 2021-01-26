select
    decode(rdb$dependent_type
            , 0, 'table'
            , 1, 'view'
            , 2, 'trigger'
            , 3, 'computed_field'
            , 4, 'validation'
            , 5, 'procedure'
            , 7, 'exception'
            , 8, 'user'
            , 9, 'field'
            , 10, 'index'
    ) as master_type
    , rdb$dependent_name as master_name
    , decode(rdb$depended_on_type
            , 0, 'table'
            , 1, 'view'
            , 2, 'trigger'
            , 3, 'computed_field'
            , 4, 'validation'
            , 5, 'procedure'
            , 7, 'exception'
            , 8, 'user'
            , 9, 'field'
            , 10, 'index'
            , 11, 'generator'
            , 14, 'External Functions'
            , 15, 'Encryption'
    ) as slave_type
    , rdb$depended_on_name as slave_name
    , rdb$field_name
from rdb$dependencies

