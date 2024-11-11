set term ^ ;

create or alter procedure aux_validate_policy_number(
    policy_number varchar(255)
)
returns (
    is_correct boolean
    , error_code bigint
    , error_text varchar(1024)
    , current_check_digit smallint
    , correct_check_digit smallint
    , correct_policy_number varchar(255)

    , number_by_even_digits varchar(16) -- число из четных цифр номера в обратном порядке
    , number_by_odd_digits varchar(16) -- число из нечетных цифр номера в обратном порядке
    , check_number varchar(255)
    , check_value bigint
)
as
declare idx smallint;
declare digit smallint; -- число из четных цифр номера в обратном порядке
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    error_code = 0;
    error_text = '';
    is_correct = True;

    policy_number = trim(policy_number);

    -- Проверка полиса ОМС единого образца
    -- на соответствие формату
    -- XXXXXXXXXXXXXXXK – номер полиса ОМС
    -- К – контрольный разряд номера полиса ОМС, вычисляется арифметически в соответствии с методикой расчета,
    -- описанной в международном стандарте ISO/HL7 27931:2009 (алгоритм Mod10):
    -- a) выбираются нечетные цифры по порядку, начиная справа, в виде числа,
    -- и умножается это число на 2.
    -- b) выбираются четные цифры по порядку, начиная справа, в виде числа,
    -- и результат приписывается слева от числа, полученного в пункте a).
    -- c) складываются все цифры полученного в пункте b) числа.
    -- d) полученное в пункте c) число вычитается из ближайшего большего или равного числа, кратного 10.
    -- В результате получается искомая контрольная цифра.
    -- (источник: https://rostov-tfoms.ru/o-fonde/103-servisy/364-struktura-edinogo-nomera-polisa-enp-obyazatelnogo-meditsinskogo-strakhovaniya)
    --
    -- Для вычисления контрольной цифры по схеме Mod10 используется следующий алгоритм:
    -- Предположим, что задан идентификатор 12345. Возьмите цифры, стоящие на нечетных позициях (по порядку справа налево), и умножьте записанное ими число, а именно, 531, на 2. В результате получится 1062. Возьмите цифры, стоящие на четных позициях
    -- (по порядку справа налево), а именно, 42, и припишите их перед результатом предыдущего умножения (1062). Получится число 421062. Сложите все шесть цифр (получится 15) и
    -- вычтите это число из ближайшего большего или равного кратного числа 10, а именно, 20.
    -- В результате получится однозначное число 5. Таким образом, для идентификатора 12345
    -- контрольная цифра по схеме Мос110 равна 5. Для числа 401 контрольная цифра по схеме
    -- Mod10 равна 0; для числа 9999 - 4; для 99999999 - 8.
    -- (источник: Health Level Seven Version 2.5.
    -- Прикладной протокол электронного обмена
    -- данными в организациях здравоохранения
    -- (ISO/HL7 27931:2009, Data Exchange Standards — Health Level Seven Version 2.5 — An application protocol for electronic data exchange in healthcare environments, IDT)
    -- https://files.stroyinf.ru/Data2/1/4293751/4293751663.pdf)
    if (char_length(policy_number) is distinct from 16
        or policy_number not similar to '[0-9]{16}') then
    begin
        error_code = 1;
        error_text = 'Полис ОМС единого образца должен содержать только 16 цифр';
    end
    else
    begin
        idx = char_length(policy_number);

        current_check_digit = substring(policy_number from idx for 1);
        idx = idx - 1;

        number_by_even_digits = '';
        number_by_odd_digits = '';
        while (idx > 0) do
        begin
            digit = substring(policy_number from idx for 1);

            if (mod(idx, 2) = 0) then
            begin
                number_by_even_digits = number_by_even_digits || digit;
            end
            else number_by_odd_digits = number_by_odd_digits || digit;

            idx = idx - 1;
        end

        check_number = number_by_even_digits || (cast(number_by_odd_digits as bigint) * 2);
        idx = char_length(check_number);
        check_value = 0;
        while (idx > 0) do
        begin
            digit = substring(check_number from idx for 1);
            check_value = check_value + digit;
            idx = idx - 1;
        end

        correct_check_digit = right(10 - mod(check_value, 10), 1);

        if (current_check_digit is distinct from correct_check_digit) then
        begin
            error_code = 2;
            error_text = 'Неверная контрольная цифра';
            correct_policy_number = substring(policy_number from 1 for char_length(policy_number) - 1)
                                        || correct_check_digit;
        end
        else correct_policy_number = policy_number;
    end

    -----------------------------------------


    if (error_code > 0)
        then is_correct = False;

    suspend;
end^

set term ; ^