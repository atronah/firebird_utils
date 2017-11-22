set term ^ ;

/* Normalize passed name
Transforn name to a form, that satisfies the following conditions:
- First letter is upper case
- All except first letter are lower case
- Does not contain trailing and leading whitespaces

Not yet implemented:
- Name contains only allowed letters, specified in `allowed_chars` argument
- First letter of each name part is upper case (parts delimiter chars speicified in `delimiter` argument)
*/
create or alter procedure mds_aux_norm_name(
    name varchar(255)
)
returns(
    norm_name varchar(255)
)
as
declare name_length bigint;
begin
    name = trim(name);
    name_length = char_length(name);
    norm_name = upper(left(name, 1)) 
                || iif(name_length > 1
                        , lower(substring(name from 2))
                        , '');
    suspend;
end^

set term ; ^