set term ^ ;

create or alter procedure aux_strip_string(
    input_string varchar(1024)
    , char_list varchar(255)
    , replace_with_char char(1) = ''
    , inverse smallint = 0
)
returns(
    str varchar(1024)
    , str_len bigint
)
as
declare symbol char(1);
declare symbol_index bigint;
begin
    str_len = char_length(input_string);
    symbol_index = 0;
    str = '';

    while (symbol_index < str_len) do
    begin
        symbol_index = symbol_index + 1;
        symbol = substring(input_string from symbol_index for 1);

        str = str || trim(iif((inverse = 0 and char_list not like '%' || symbol || '%')
                                or (inverse > 0 and char_list like '%' || symbol || '%')
                              , symbol
                              , replace_with_char));
    end

    suspend;
end^

set term ; ^