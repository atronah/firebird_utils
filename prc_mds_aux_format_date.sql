set term ^ ;

/*! \fn mds_aux_format_date
    \brief преобразует дату и время \a datetime в строку \a datestr согласно указанному формату \a format
    \param datetime исходные дата и время
    \param format строка форматирования даты
    \param[out] string результат преобразования

    Строка форматирования чувствительна к регистру и поддерживает модификаторы:
        - "d" или "dd" - день
        - "M" или "MM" - месяц
        - "yy" или "yyyy" - год
        - "h" или "hh" - час
        - "m" или mm - минута
        - "s" или "ss" - секунда
*/

create or alter procedure mds_aux_format_date(
  datetime timestamp,
  format varchar(255) = ''
)
returns(
  string varchar(255)
)
as
declare val integer;
begin
    if (format containing 'd') then
    begin
        val = extract(day from datetime);
        format = replace(format, 'dd', lpad(val, 2, '0'));
        format = replace(format, 'd', val);
    end

    if (format containing 'M') then
    begin
        val = extract(month from datetime);
        format = replace(format, 'MM', lpad(val, 2, '0'));
        format = replace(format, 'M', val);
    end

    if (format containing 'y') then
    begin
        val = extract(year from datetime);
        format = replace(format, 'yyyy', val);
        format = replace(format, 'yy', right(val, 2));
    end

    if (format containing 'h') then
    begin
        val = extract(hour from datetime);
        format = replace(format, 'hh', lpad(val, 2, '0'));
        format = replace(format, 'h', val);
    end

    if (format containing 'm') then
    begin
        val = extract(minute from datetime);
        format = replace(format, 'mm', lpad(val, 2, '0'));
        format = replace(format, 'm', val);
    end

    if (format containing 's') then
    begin
        val = extract(second from datetime);
        format = replace(format, 'ss', lpad(val, 2, '0'));
        format = replace(format, 's', val);
    end

    string = format;
    suspend;
end^

set term ; ^