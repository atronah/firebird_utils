set term ^ ;

/*! \fn mds_aux_regexp_search
    \brief search first match in \a text for passed regular expression \s pattern
    \param pattern regexp pattern
    \param text Text for search
    \param syntax Syntax of regular expression: 0 - firebird, 1 - common (partially supported)
    \param only_first shows only first match (if above 0), otherwise shows all matches
    \param[out] match First match
    \param[out] startpos position of \a match in \a text
*/
create or alter procedure mds_aux_regexp_search(
    pattern blob sub_type text,
    text blob sub_type text,
    syntax smallint = 0,
    only_first smallint = 1
)
returns(
    match blob sub_type text,
    startpos bigint
)
as
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    for select
            rs.match, rs.startpos
        from aux_regexp_search(:pattern, :text, :syntax, :only_first) as rs
        into match, startpos
    do
    begin
        suspend;
    end
end^

set term ; ^