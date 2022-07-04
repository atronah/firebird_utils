set term ^ ;

create or alter procedure aux_split_person_name(
    fullname varchar(255)
)
returns(
    lastname varchar(64)
    , firstname varchar(64)
    , midname varchar(64)
)
as
declare pos bigint;
declare len bigint;
declare c varchar(1);
declare prev_c varchar(1);
declare state smallint;
declare STATE_BEFORE_LASTNAME smallint = 0;
declare STATE_LASTNAME smallint = 1;
declare STATE_BEFORE_FIRSTNAME smallint = 2;
declare STATE_FIRSTNAME smallint = 3;
declare STATE_BEFORE_MIDNAME smallint = 4;
declare STATE_MIDNAME smallint = 5;
begin
    pos = 1;
    len = char_length(fullname);

    state = STATE_BEFORE_LASTNAME;
    lastname = ''; firstname = ''; midname = '';
    while (pos <= len) do
    begin
        prev_c = c;
        c = substring(fullname from pos for 1);
        pos = pos + 1;

        if (c = ' ' and state not in (STATE_BEFORE_LASTNAME, STATE_BEFORE_FIRSTNAME, STATE_BEFORE_MIDNAME)) then
        begin
            state = state + 1;
            continue;
        end
        else if (c similar to '[[:ALPHA:]А-ЯЁ]' and prev_c is distinct from upper(prev_c)) then
        begin
            state = state + 1;
        end

        if (upper(c) similar to '[-()[:ALPHA:]А-ЯЁ.]') then
        begin
            if (state in (STATE_BEFORE_LASTNAME, STATE_BEFORE_FIRSTNAME, STATE_BEFORE_MIDNAME))
                then state = state + 1;

            if (state = STATE_LASTNAME)
                then lastname = lastname || c;
            else if (state = STATE_FIRSTNAME)
                then firstname = firstname || c;
            else if (state = STATE_MIDNAME)
                then midname = midname || c;
        end

        if (c = '.' and state not in (STATE_BEFORE_LASTNAME, STATE_BEFORE_FIRSTNAME, STATE_BEFORE_MIDNAME))
            then state = state + 1;

        if (state > STATE_MIDNAME and pos < len) then
        begin
            lastname = lastname || ' ' || firstname;
            firstname = midname;
            midname = '';
            state = STATE_BEFORE_MIDNAME;
        end
    end
    suspend;
end^

set term ; ^
