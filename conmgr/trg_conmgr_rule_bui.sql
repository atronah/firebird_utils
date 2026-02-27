set term ^ ;

create or alter trigger conmgr_rule_bui
    active
    before update or insert
    on conmgr_rule
as
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master/conmgr

    new.rule_id = coalesce(new.rule_id, old.rule_id, next value for conmgr_rule_seq);
    new.rule_type = upper(trim(new.rule_type));

    when any do
    begin
    end
end^

set term ; ^
