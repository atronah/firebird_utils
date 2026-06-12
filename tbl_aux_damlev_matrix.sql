create global temporary table aux_damlev_matrix (
    r bigint
    , c bigint
    , v bigint
    , constraint pk_aux_damlev_matrix primary key (r, c)
) on commit delete rows;


comment on table aux_damlev_matrix is 'The temporary table to store 2d-matrix that used in Wagner–Fischer algorithm for calculating Damerau-Levenshtein distance for two strings by procedure aux_damlev_distance.

------
author: atronah (look for me by this nickname on GitHub and GitLab)
source: https://github.com/atronah/firebird_utils/tree/master
';

comment on column aux_damlev_matrix.r is 'Row number of matrix';
comment on column aux_damlev_matrix.c is 'Column number of matrix';
comment on column aux_damlev_matrix.v is 'Value of cell with the row number `r` and the column number `c`';