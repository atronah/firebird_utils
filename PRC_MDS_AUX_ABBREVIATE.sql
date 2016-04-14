set term ^ ;

/*! \fn mds_aux_abbreviate
    \brief Формирует аббревиатуру на основе переданного текста
    \param str Исходный текст для формирования аббревиатуры
    \param parts_limit максимальное число итоговых блоков аббревиатуры (подряд идущие цифры или заглавные буквы исходного текста считаются одним блоком)
    \param skip_lower если не 0 и не null, то пропускаются блоки, начинающиеся со строчной буквы

    Процедура формирования аббревиатуры из текста, которая сокращает блоки текста до первой буквы.
    Под отдельным блоком текста подразумеваются максимально длинные фрагменты текста,
    состоящие тольоко из букв одного алфавита или из цифр. При этом окончанием блока считается: смена алфавита,
    появление небуквенного и нецифрового символа, переход от цифр к буквам и наоборот, переход от строчной буквы к прописной даже в рамках одного алфавита.
    Пример:
    'Иванов ИВан-ЮSupov IV именуемый 192.87ым' -> 'И' + 'ИВ' + 'Ю' + 'S' + 'IV' + 'и' + '192.87' -> 'ИИВЮSIVи192.87'
*/

create or alter procedure mds_aux_abbreviate(
  str blob sub_type text
  , parts_limit smallint =  null
  , skip_lower smallint = 0
)
returns(
  abbr blob sub_type text
)
as
declare pos bigint;
declare source_length bigint;
declare next_delimiter bigint;
declare word varchar(256);
declare c varchar(1);
declare c_type smallint;
declare prev_c_type smallint;
declare part_number bigint;
begin
    if (str is null) then exit;
    
    abbr = '';
    str = trim(str);
    pos = 1;
    prev_c_type = 6;
    part_number = 0;
    source_length = char_length(str);
    skip_lower = coalesce(skip_lower, 0);

    while (pos <= source_length
                and (parts_limit is null or part_number < parts_limit)
    ) do
    begin
        c = substring(str from pos for 1);
        c_type = case
                    when c similar to '[a-z]' then 0 -- lower english
                    when c similar to '[A-Z]' then 1 -- upper english
                    when c similar to '[а-яё]' then 2 -- lower russian
                    when c similar to '[А-ЯЁ]' then 3 -- upper russian
                    when c similar to '[0-9]' then 4 -- digits
                    when c similar to '[.,]' then 5 -- digits
                    else 6 -- other symbols
                end;
        -- add current character to abbr if current character is not symbol
        -- and either prev character was symbol
        --      or current character changes type from lower to upper
        --      or current character changes language
        --      or current character is UPPER or DIGIT
        if (c_type <> 6
                -- character type changed from "other symbol" plus checking for skip lower case
            and ((prev_c_type = 6 and (skip_lower = 0 or c_type not in (0, 2)))
                    -- current character is lower english and previous is not another english character in any case and not digit
                    or (c_type = 0 and prev_c_type not in (0, 1, 4) and skip_lower = 0)
                    -- current character is lower russian and previous is not another russian character in any case and not digit
                    or (c_type = 2 and prev_c_type not in (2, 3, 4) and skip_lower = 0)
                    -- current character is dot and previous is digit
                    or (c_type = 5 and prev_c_type = 4)
                    -- current character is any upper case or digit
                    or (c_type in (1, 3, 4))
            )) then
        begin
            abbr = abbr || c;
            if (c_type <> prev_c_type) then part_number = part_number + 1;
        end
        prev_c_type = c_type;
        pos = pos + 1;
    end
    suspend;
end^

set term ; ^