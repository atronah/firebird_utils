execute block
returns(
    stm varchar(60),
    tname varchar(128),
    cnt bigint,
    delete_stmt varchar(60)
) as
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

	for select
            trim(r.rdb$relation_name)
        from rdb$relations as r
        where coalesce(r.rdb$system_flag, 0) = 0
            and coalesce(rdb$relation_type, 0) = 0
        order by 1
    into :tname do
	begin
		stm = 'select count(*) from "' || tname || '"';
        delete_stmt = 'delete from "' || tname || '";';
		execute statement :stm into :cnt;

		if (cnt > 0) then suspend;
	end
end
