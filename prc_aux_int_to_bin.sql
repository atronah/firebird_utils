set term ^ ;

create or alter procedure aux_int_to_bin(
    int_data bigint
    , ajust_size bigint = 4
)
returns(
    bin_data varchar(16000)
)
as
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    bin_data = '';

    while (int_data > 1) do
    begin
        bin_data = iif(bin_and(int_data, 1) > 0, '1', '0') || bin_data;
        int_data = bin_shr(int_data, 1);
    end
    bin_data = int_data || bin_data;

    if (ajust_size > 0)
        then bin_data = lpad(bin_data, ajust_size * ((char_length(bin_data) - 1) / ajust_size + 1), '0');
    suspend;
end^

set term ; ^

comment on procedure aux_int_to_bin is 'Returns binary string representation of integer number';
comment on parameter aux_int_to_bin.int_data is 'Integer number to format in binary form';
comment on parameter aux_int_to_bin.ajust_size is 'Minimum size of digits block to ajust result, default 4 digits (`01` will be ajusted to `0010`, `11011` - to `00011010`)';
comment on parameter aux_int_to_bin.bin_data is 'Binary form of passed integer number';
