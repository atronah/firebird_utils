set term ^ ;

create or alter trigger conmgr_log_bui
    active
    before update or insert
    on conmgr_log
as
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master/conmgr

    new.log_id = coalesce(new.log_id, old.log_id, next value for conmgr_log_seq);
    new.logged = coalesce(new.logged, old.logged, cast('now' as timestamp));

    when any do
    begin
    end
end^

set term ; ^