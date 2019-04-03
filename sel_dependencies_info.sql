select distinct
   decode(rdb$dependent_type
            , 0, 'table'
            , 1, 'view'
            , 2, 'trigger'
            , 3, 'computed column'
            , 4, 'check constraint'
            , 5, 'procedure'
            , 6, 'index expression'
            , 7, 'exception'
            , 8, 'user'
            , 9, 'column'
            , 10, 'index'
    ) as slave_type
   , rdb$dependent_name as slave_name
   , decode(RDB$DEPENDED_ON_TYPE
            , 0, 'table'
            , 1, 'view'
            , 2, 'trigger'
            , 3, 'computed column'
            , 4, 'check constraint'
            , 5, 'procedure'
            , 6, 'index expression'
            , 7, 'exception'
            , 8, 'user'
            , 9, 'column'
            , 10, 'index'
            , 14, 'generator (sequence)'
            , 15, 'udf'
            , 17, 'collation'
    ) as related_type
   , rdb$depended_on_name as related_name
from rdb$dependencies