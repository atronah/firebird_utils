set term ^ ;

create or alter procedure get_damerau_levenshtein(
    s1 varchar(1024)
    , s2 varchar(1024)
)
returns (
    distance bigint
)
as
declare current_row bigint;	-- current row of matrix (0 .. length(s1))
declare current_col bigint;	-- current column of matrix (0 .. length(s2))
declare s1_len bigint;	-- first\left\s1 string length
declare s2_len bigint;	-- second\right\s2 string length
declare replace_distance bigint;	-- current distance for replace operation
declare insert_distance bigint;		-- current distance for insert operation
declare delete_distance bigint;		-- current distance for delete operation
declare tmp varchar(1024); -- for swapping values of string

declare current_row_distances varchar(4096); -- previous row of matrix in string format (column values separated by comma) 
declare prev_row_distances varchar(4096); -- current row of matrix (column values separated by comma)
begin
    s1_len = char_length(s1);
    s2_len = char_length(s2);
    
    -- for equivalent strings number of operations is zero
    if  (s1 like s2) then distance = 0;
    -- for empty string number of operations is equal number of characters other string
    else if (s1_len = 0) then distance = s2_len;
    else if (s2_len = 0) then distance = s1_len;
    else
    begin
        -- optimization
        if (s1_len > s2_len) then
        begin 
            tmp = s1;
            s1 = s2;
            s2 = tmp;
            
            s1_len = char_length(s1);
            s2_len = char_length(s2);
        end
        
        current_col = 0;
        
        -- first row of distance value matrix contain number from 0 to length second string
        while (current_col <= s2_len) do
        begin
            prev_row_distances = coalesce(prev_row_distances || ',', '') || current_col;
            current_col = current_col + 1;
        end

        current_row = 1; -- second row of distance matrix and first character in s1 string
        
        -- for reference:
        -- `select part from aux_split_text(:prev_row_distances) where idx = (:current_col + 1)`
        -- returns item from list `prev_row_distances` with index = <current_col> (i.e. `prev_row_distances[current_col]`)
        -- `current_col + 1` in query needs because start index for result of `aux_split_text` procedure is 1, not 0 as in lists.
        while (current_row <= s1_len) do
        begin
            current_row_distances = current_row;
            
            current_col = 1; -- 1 - second column in matrix and first character in s2_len
            while (current_col <= s2_len) do
            begin
                -- if s1[row] = s2[column] then do not increment the counter operations (d[row, column] = d[row - 1, column -1])
                if (-- compared characters are equal (s1[r] = s2[c])
                    substring(s1 from current_row for 1) = substring(s2 from current_col for 1) 
                    -- or it is transposition (s1[r] = s2[c - 1] and s1[r] = s2[c - 1])
                    or (current_row > 1 and substring(s1 from current_row - 1 for 1) = substring(s2 from current_col for 1)
                        and current_col > 1 and substring(s1 from current_row for 1) = substring(s2 from current_col - 1 for 1))
                ) then  -- adds into d[r,c] value d[r-1, c-1] 
                        current_row_distances = current_row_distances || ',' || (select part from aux_split_text(:prev_row_distances) where idx = (:current_col + 1) - 1);
                else
                -- adds into d[r,c] min value of d[r-1,c-1], d[r,c-1], d[r-1,c]
                begin
                    -- previous distance for "replace" operation in d[row - 1, column -1]
                    replace_distance = (select cast(part as bigint) from aux_split_text(:prev_row_distances) where idx = (:current_col + 1) - 1) + 1;

                    -- previous distance for "insert" operation in d[row, column -1]
                    insert_distance = (select cast(part as bigint) from aux_split_text(:current_row_distances) where idx = (:current_col + 1) - 1) + 1;
                    
                    -- previous distance for "delete" operation in d[row - 1, column]
                    delete_distance = (select cast(part as bigint) from aux_split_text(:prev_row_distances) where idx = (:current_col + 1)) + 1;
                    
                    current_row_distances = current_row_distances || ',' || minvalue(replace_distance, insert_distance, delete_distance);
                end
                
                current_col = current_col + 1;
            end
            
            current_row = current_row + 1;
            prev_row_distances = current_row_distances;
        end
    
        distance = (select part from aux_split_text(:prev_row_distances) where idx = :s2_len + 1);
    end
    
    suspend;
end^

set term ; ^

comment on procedure get_damerau_levenshtein is 'returns domerau-levenshtein distance, i.e. minimal number of char operations (cut, paste, replace, transposition) for two string';