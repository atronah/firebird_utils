set term ^ ;

-- Получает значение XML-узла с указанным именем node_name из xml_source
create or alter procedure aux_string_to_type(
    source_string blob sub_type text
    , vtype varchar(16)= 'str' -- expected type. supported options: str, int (long), float (double), bool, date, time, datetime
)
returns (
    val_string blob sub_type text, -- representation of source_string as text
    val_int bigint, -- representation of source_string as integer
    val_float float, -- representation of source_string as float
    val_double double precision, -- representation of source_string as double
    val_date date, -- representation of source_string as date
    val_time time, -- representation of source_string as time
    val_datetime timestamp, -- representation of source_string as date and time
    time_zone smallint, -- time zone for date or time value in source string
    date_pattern varchar(128), -- regexp for date
    time_delim varchar(2), -- delimiter between date and time
    time_pattern varchar(64), -- regexp for date
    time_zone_pattern varchar(32), -- regexp for timezone info
    error_code smallint, -- error code. `0` if there is no errors.
    error_text varchar(1024) -- error description. empty if there is no errors.
)
as
declare time_temp_val varchar(128);
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    error_code = 0;
    error_text = '';

    vtype = lower(vtype);

    if (source_string is not null) then
    begin
        val_string = source_string;

        if (left(vtype, 3) = 'int' or left(vtype, 4) = 'long') then
        begin
            if (source_string similar to '($+|$-)?[0-9]+' escape '$') then
            begin
                val_int = cast(source_string as bigint);
                val_float = val_int;
                val_double = val_int;
            end
            else if (source_string <> '') then
            begin
                error_code = 1;
                error_text = 'Value "' || :source_string || '" is not integer number';
            end
        end
        else if (vtype in ('float', 'double')) then
        begin
            if (source_string similar to '($+|$-)?([0-9]+(.[0-9]*)?|.[0-9]+)' escape '$') then
            begin
                val_float = cast(source_string as float);
                val_double = cast(source_string as double precision);
            end
            else if (source_string <> '') then
            begin
                error_code = 2;
                error_text = 'Value "' || :source_string || '" is not real number';
            end
        end
        else if (vtype in ('bool', 'boolean')) then
        begin
            val_int = case
                            when lower(trim(source_string)) in ('true', 't', '1') then 1
                            when lower(trim(source_string)) in ('false', 'f', '0') then 0
                            else null
                        end;
            if (val_int is null) then
            begin
                error_code = 3;
                error_text = 'Value "' || :source_string || '" is not boolean';
            end
        end
        else if (vtype in ('date', 'time', 'datetime')) then
        begin
            -- todo: with source_string `2017-10-01 00:01.4444` works incorrectly
            time_temp_val = replace(trim(upper(source_string)), 'T', ' ');
            time_zone = 0;
            date_pattern = '(' -- start of date part
                            || '[0-9]{4}$-[0-9]{1,2}$-[0-9]{1,2}' -- Dates like 2000-01-01
                            || '|' -- or
                            || '[0-9]{1,2}.[0-9]{1,2}.[0-9]{1,4}' -- Dates like 01.01.00
                            || ')'; -- end of date part
            time_delim = ' '; -- delimiter between date and time
            time_pattern = '([0-9]{1,2}:[0-9]{1,2}(:[0-9]{1,2})?(.[0-9]+)?)'; -- time like 01:01:01.1111
            time_zone_pattern = '(($+|$-)[0-9]{2}:[0-9]{2})'; -- timezone like +00:00

            if (right(time_temp_val, 1) = 'Z') then
            begin
                time_zone = 0;
                time_temp_val = left(time_temp_val, char_length(time_temp_val) - 1);
            end
            else if (right(time_temp_val, 6) similar to time_zone_pattern escape '$') then
            begin
                time_zone = cast(left(right(time_temp_val, 6), 3) as smallint);
                time_temp_val = left(time_temp_val, char_length(time_temp_val) - 6);
            end

            if (time_temp_val similar to date_pattern
                                    || '('
                                            || time_delim
                                            || time_pattern || '?'
                                    || ')?'
                                    escape '$'
            ) then
            begin
                val_datetime = cast(left(time_temp_val, 19) as timestamp);

                val_time = cast(val_datetime as time);
                val_date = cast(val_datetime as date);
            end
            else if (time_temp_val similar to time_pattern escape '$')
                then val_time = cast(left(time_temp_val, 8) as time);
            else if (source_string <> '') then
            begin
                error_code = 4;
                error_text = 'Value "' || :source_string || '" is not date or time';
            end
        end
    end

    suspend;
end^

set term ; ^