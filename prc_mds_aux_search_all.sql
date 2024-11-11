create or alter procedure mds_aux_search_all(
    text blob sub_type text
)
returns (
    ftable varchar(31)
    , fname varchar(31)
    , ftype varchar(31)
    , cnt bigint
)
as
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    if(coalesce(:text, '') = '' ) then exit;
    for select
            trim(rdb$field_name) as fname
            , trim(rdb$relation_name) as ftable
            , trim(rdb$field_source) as ftype
        from rdb$relation_fields
        where rdb$field_source not containing '$'
                and (rdb$field_source containing 'text'
                    or rdb$field_source containing 'code'
                    or rdb$field_source containing 'ident')
    into fname, ftable, ftype do
    begin
        execute statement ('select count(*) from ' || :ftable || ' where upper(:text) = upper(cast("' || :fname || '" as varchar(16000)))') (text := :text)
        into cnt;
        if (cnt > 0) then suspend;
    end
end