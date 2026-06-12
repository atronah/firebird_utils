set term ^ ;

create or alter procedure aux_damlev_distance(
    src varchar(4096)
    , trg varchar(4096)
    , details_mode smallint = null
)
returns (
    distance bigint
    , len1 bigint
    , len2 bigint

    , matrix blob sub_type text

    , details varchar(12288)
)
as
declare r type of column aux_damlev_matrix.r;
declare c type of column aux_damlev_matrix.c;
declare v type of column aux_damlev_matrix.v;
declare matrix_line varchar(16392);
declare cost smallint;
declare new_r type of column aux_damlev_matrix.r;
declare new_c type of column aux_damlev_matrix.c;
declare min_v type of column aux_damlev_matrix.v;
declare operation varchar(2);
declare src_symbols varchar(2);
declare trg_symbols varchar(2);
declare operations_line varchar(4096);
declare src_line varchar(4096);
declare trg_line varchar(4096);
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master

    details_mode = coalesce(details_mode, 0);

    distance = 0;
    matrix = '';

    if (src is not distinct from trg) then
    begin
        suspend;
        exit;
    end

    len1 = char_length(src);
    len2 = char_length(trg);

    -- initiating first row of matrix
    r = 0;
    while (r <= len1) do
    begin
        update or insert into aux_damlev_matrix(r, c, v)
            values (:r, 0, :r);
        r = r + 1;
    end

    -- initiating first column of matrix
    c = 0;
    matrix_line = lpad('.', 4, ' ') || lpad('.', 4, ' ');
    while (c <= len2) do
    begin
        update or insert into aux_damlev_matrix(r, c, v)
            values (0, :c, :c);

        if (c > 0)
            then matrix_line = matrix_line || lpad(substring(trg from c for 1), 4, ' ');
        c = c + 1;
    end
    matrix = matrix || matrix_line || ascii_char(10);

    -- preparing second row of result matrix
    c = 0; matrix_line = lpad('.', 4, ' ');
    while (c <= len2) do
    begin
        matrix_line = matrix_line || lpad(c, 4, ' ');
        c = c + 1;
    end
    matrix = matrix || matrix_line || ascii_char(10);

    r = 1;
    while (r <= len1) do
    begin
        matrix_line = lpad(substring(src from r for 1), 4, ' ') || lpad(r, 4, ' ');

        c = 1;
        while (c <= len2) do
        begin
            cost = iif(substring(src from r for 1) = substring(trg from c for 1), 0, 1);
            v = minvalue(
                -- deletion
                (select v + 1
                    from aux_damlev_matrix
                    where r = (:r - 1) and c = :c)
                -- insertion
                , (select v + 1
                    from aux_damlev_matrix
                    where r = :r and c = (:c - 1))
                -- substitution
                , (select v + :cost
                    from aux_damlev_matrix
                    where r = (:r - 1) and c = (:c - 1))
            );

            -- transposition
            if (r > 1 and c > 1
                and substring(src from r - 1 for 1) = substring(trg from c - 1 for 1)
            ) then
            begin
                v = minvalue(
                    v
                    , (select v + :cost
                        from aux_damlev_matrix
                        where r = (:r - 2) and c = (:c - 2))
                );
            end

            update or insert into aux_damlev_matrix(r, c, v)
                values (:r, :c, :v);

            matrix_line = matrix_line || lpad(v, 4, ' ');

            c = c + 1;
        end

        matrix = matrix || matrix_line || ascii_char(10);

        r = r + 1;
    end

    distance = v;


    if (details_mode = 1) then
    begin
        details = '';
        operations_line = '';
        src_line = '';
        trg_line = '';

        r = len1; c = len2;
        min_v = distance;
        while (r > 0 or c > 0) do
        begin
            operation = '.';
            src_symbols = '.';
            trg_symbols = '.';

            if (r > 0) then
            begin
                v = (select v
                            from aux_damlev_matrix
                            where r = (:r - 1) and c = :c);
                if (v <= min_v) then
                begin
                    min_v = v;
                    new_r = r - 1; new_c = c;
                    operation = 'D';
                    src_symbols = substring(src from r for 1);
                    trg_symbols = '.';
                end
            end

            if (c > 0) then
            begin
                v = (select v
                            from aux_damlev_matrix
                            where r = :r and c = (:c - 1));
                if (v <= min_v) then
                begin
                    min_v = v;
                    new_r = r; new_c = c - 1;
                    operation = 'I';
                    src_symbols = '.';
                    trg_symbols = substring(trg from c for 1);
                end
            end

            if (r > 0 and c > 0) then
            begin
                v = (select v
                            from aux_damlev_matrix
                            where r = (:r - 1) and c = (:c - 1));
                if (v <= min_v) then
                begin
                    min_v = v;
                    new_r = r - 1; new_c = c - 1;
                    src_symbols = substring(src from r for 1);
                    trg_symbols = substring(trg from c for 1);
                    operation = iif(src_symbols = trg_symbols, 'N', 'S');
                end
            end

            if (r > 1 and c > 1
                    and substring(src from r for 1) = substring(trg from c - 1 for 1)
                    and substring(trg from c for 1) = substring(src from r - 1 for 1)
            ) then
            begin
                v = (select v
                        from aux_damlev_matrix
                        where r = (:r - 2) and c = (:c - 2));

                if (v <= min_v) then
                begin
                    min_v = v;
                    new_r = r - 2; new_c = c - 2;
                    operation = 'T.';
                    src_symbols = substring(src from r - 1 for 1) || substring(src from r for 1);
                    trg_symbols = substring(trg from c - 1 for 1) || substring(trg from c for 1);
                end
            end

            r = new_r; c = new_c;
            operations_line = trim(operation) || operations_line;
            src_line = trim(src_symbols) || src_line;
            trg_line = trim(trg_symbols) || trg_line;
        end

        details = operations_line || ascii_char(10)
                || src_line || ascii_char(10)
                || trg_line;
    end


    suspend;
end^

set term ; ^

comment on procedure aux_damlev_distance is 'Calculate Damerau-Levenshtein distance for two strings,
i.e. the minimum number of operations (consisting of insertions, deletions
or substitutions of a single character, or transposition of two adjacent characters)
required to change one word into the other.

Let''s take two strings as an example:

- source string: "zabcd"
- target string: "xbdc"

Transformation the source string to the target string required 4 simple operations:
    `z` -> `.` - (1) [D]eleting
    `a` -> `x` - (2) [S]ubstituting
    `b` -> `b` - (-) [N]othing
    `c` -> `d` - (3) [T]ransposition
    `d` -> `c` - (4) [T]ransposition

Matrix of Wagner–Fischer algorithm (value of `matrix` output parameter) will be:
   .   .   x   b   d   c
   .   0   1   2   3   4
   z   1   1   2   3   4
   a   2   2   2   3   4
   b   3   3   2   3   4
   c   4   4   3   3   3
   d   5   5   4   3   4

Value of `details` output parameter (for `details_mode = 1`) will be:
DSNT.
zabcd
.xbdc


------
author: atronah (look for me by this nickname on GitHub and GitLab)
source: https://github.com/atronah/firebird_utils/tree/master
';

comment on parameter aux_damlev_distance.src is 'Source string';
comment on parameter aux_damlev_distance.trg is 'Target string';
comment on parameter aux_damlev_distance.details_mode is 'Specifies content for `details` output parameter:

- null/0 - do not make `details`
- `1` - `details` will contains 3 lines:
    - first line with sequence of operatoions that represented by one-character codes:
        - [N]othing - keeping character in the source string without changes
        - [D]eleting - removing character from the source string
        - [I]nserting - adding new character into the source string
        - [S]ubstituting - replacing character from the source string to character of the target string
        - [T]ransposition - swap the character of the source string with the next character of the source string
    - second line with sequence of the source string characters that involved in the operations (on the same place in the first line of details)
    - third line with sequence of the target string characters that involved in the operations (on the same place in the first line of details)
';
comment on parameter aux_damlev_distance.distance is 'The minimum number of operations (consisting of insertions, deletions
or substitutions of a single character, or transposition of two adjacent characters)
required to change one word into the other.';
comment on parameter aux_damlev_distance.len1 is 'Length of first string `src`';
comment on parameter aux_damlev_distance.len2 is 'Length of second string `trg`';

comment on parameter aux_damlev_distance.matrix is 'String representation of a matrix that used in Wagner–Fischer algorithm for calculating distance.';

comment on parameter aux_damlev_distance.details is 'Detailed info about operations, required to transform first string to second string.
Content depends on the value of input parameter `details_mode`';
