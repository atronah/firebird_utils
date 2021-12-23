set term ^ ;

create or alter procedure aux_utf8_to_utf16(
    utf8_data blob sub_type text
)
returns(
    error_code bigint
    , error_text varchar(1024)
    , utf16_data blob sub_type text
    , utf8_data_len bigint
)
as
declare pos bigint;
declare utf8_block_char varchar(1);
declare utf8_block_char_int bigint;
declare utf8_block_data_int bigint;
declare unicode_code bigint;
declare extra_block_count smallint;
declare data_mask bigint;
declare data_buffer varchar(32000);
declare data_buffer_len bigint;
-- Constants
declare BUFFER_LIMIT bigint = 16000;
-- -- block prefixes
declare CODING_BY_8BIT smallint = 0; -- 0xxxxxxx
declare CODING_BY_16BIT smallint = 192; -- 110xxxxx
declare CODING_BY_24BIT smallint = 224; -- 1110xxxx
declare CODING_BY_32BIT smallint = 240; -- 11110xxx
declare EXTRA_BLOCK smallint = 128; -- 10xx xxxx
-- -- bit masks
declare FIRST_BIT_MASK smallint = 128; -- 1000 0000 (to check x... .... for 8 bit coding)
declare FIRST_TWO_BITS_MASK smallint = 192; -- 1100 0000 (to check xx.. .... for extra block)
declare FIRST_THREE_BITS_MASK smallint = 224; -- 1110 0000 (to check xxx. .... for 16 bit coding)
declare FIRST_FOUR_BITS_MASK smallint = 240; -- 1111 0000 (to check xxxx .... for 24 bit coding)
declare FIRST_FIVE_BITS_MASK smallint = 248; -- 1111 1000 (to check xxxx x.... for 32 bit coding)
begin
    -- based on description from https://habr.com/ru/post/544084/
    error_code = 0;
    error_text = '';
    data_buffer = '';

    utf8_data_len = char_length(utf8_data);

    if (utf8_data is null or utf8_data_len = 0) then
    begin
        utf16_data = utf8_data;
    end
    else
    begin
        utf16_data = ASCII_CHAR(255) || ASCII_CHAR(254); -- BOM (1111 1111 + 1111 1110, 0xff + 0xfe, default for utf-16)

        data_buffer_len = 0;
        extra_block_count = 0;
        pos = 1;

        while (pos <= utf8_data_len and error_code = 0) do
        begin
            utf8_block_char = substring(utf8_data from pos for 1);
            utf8_block_char_int = ascii_val(utf8_block_char);

            if (extra_block_count = 0) then
            begin
                data_mask = 0;
                unicode_code = 0; -- reset code of character

                -- first byte like 0xxxxxxx (first bit is zero)
                if (bin_and(utf8_block_char_int, FIRST_BIT_MASK) = CODING_BY_8BIT) then
                begin
                    extra_block_count = 0; -- one block (8 bits) per character
                    data_mask = 127; -- 0111 1111 (.xxx xxxx)
                end
                -- first byte like 10xxxxxx (first bit is "1" and second is "0")
                else if(bin_and(utf8_block_char_int, FIRST_TWO_BITS_MASK) = EXTRA_BLOCK) then
                begin
                    error_code = 1;
                    error_text = 'unexpected extra block (10xxxxxx at the begining of character)';
                end
                -- first byte like 110xxxxx (first bit is "1" and second is "0")
                else if (bin_and(utf8_block_char_int, FIRST_THREE_BITS_MASK) = CODING_BY_16BIT) then
                begin
                    extra_block_count = 1; -- two blocks (16 bits) per character (110xxxxx 10xxxxxx)
                    data_mask = 31; -- 0001 1111 (...x xxxx)
                end
                -- first byte like 1110xxxx
                else if (bin_and(utf8_block_char_int, FIRST_FOUR_BITS_MASK) = CODING_BY_24BIT) then
                begin
                    extra_block_count = 2; -- three blocks (24 bits) per character (1110xxxx 10xxxxxx 10xxxxxx)
                    data_mask = 15; -- 0000 1111 (.... xxxx)
                end
                -- first byte like 11110xxx
                else if (bin_and(utf8_block_char_int, FIRST_FIVE_BITS_MASK) = CODING_BY_32BIT) then
                begin
                    extra_block_count = 3; -- four blocks (32 bits) per character (11110xxx 10xxxxxx 10xxxxxx 10xxxxxx)
                    data_mask = 7; -- 0000 0111 (.... .xxx)
                    error_code = 99;
                    error_text = '32 bit encoding is not yet supported';
                end
                else
                begin
                    error_code = 2;
                    error_text = 'unexpected block (for "1" digits at the begining of character)';
                end
            end
            else
            begin
                if (bin_and(utf8_block_char_int, FIRST_TWO_BITS_MASK) is distinct from EXTRA_BLOCK) then
                begin
                    error_code = 3;
                    error_text = 'unexpected block (without 10xxxxxx at the begining)';
                end
                data_mask = 63; -- 0011 1111 (..xx xxxx)
                extra_block_count = extra_block_count - 1;
            end

            if (error_code > 0) then break;

            -- get significant bits from utf8 block
            utf8_block_data_int = bin_and(utf8_block_char_int, data_mask);

            -- shift unicode code to left (<<) for N times, where N is a number of significant bits in utf8 block
            while(data_mask > 0) do
            begin
                data_mask = bin_shr(data_mask, 1);
                unicode_code = bin_shl(unicode_code, 1);
            end

            -- add utf8 significant bits to shifted unicode code
            -- (accumulating bits of unicode code from most significant (MSB) to least (LSB) from utf8 bits)
            -- for example, if in utf8 it was "\xC5 \xB9" or "11000101 10111000" or "...00101" ..11000" or "00101 11000" or "00000001 01111000" or "376"
            --              in utf-16 it will be "01111000 "00000001" or "\x78 \x01"
            unicode_code = unicode_code + utf8_block_data_int;

            -- add to buffer resulted unicode code as 2 bytes (with LSB and later with MSB) to output utf16 data
            if (extra_block_count = 0) then
            begin
                -- first byte of unicode code (with least significant bits)
                data_buffer = data_buffer || ascii_char(bin_and(unicode_code, 255)); -- .... .... xxxx xxxx
                data_buffer_len = data_buffer_len + 1;

                -- second byte of unicode code char (with most significant bits)
                data_buffer = data_buffer || ascii_char(bin_and(bin_shr(unicode_code, 8), 255)); -- xxxx xxxx .... ....
                data_buffer_len = data_buffer_len + 1;

            end

            if (data_buffer_len > BUFFER_LIMIT) then
            begin
                utf16_data = utf16_data || data_buffer;
                data_buffer = '';
                data_buffer_len = 0;
            end

            pos = pos + 1;
        end
    end

    utf16_data = utf16_data || data_buffer;

    suspend;
end^

set term ; ^

comment on procedure aux_utf8_to_utf16 is 'Encode input utf8 data into output utf16 data (supports only 2 byte encoding of utf16)';
comment on parameter aux_utf8_to_utf16.utf8_data is 'Input data in UTF-8 encoding';
comment on parameter aux_utf8_to_utf16.error_code is 'Code of an error. If zero - encoding was successful. If more than zero - errors occured suring conversion';
comment on parameter aux_utf8_to_utf16.error_text is 'Description of an error';
comment on parameter aux_utf8_to_utf16.utf16_data is 'Encoded in UTF-16 input text';
comment on parameter aux_utf8_to_utf16.utf8_data_len is 'Number of characters in input utf8 text';
