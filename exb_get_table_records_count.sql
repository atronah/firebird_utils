execute block
returns(
    stm varchar(60),
    tname varchar(128),
    cnt bigint
) as
begin
	for select
            trim(r.rdb$relation_name)
        from rdb$relations r
        where coalesce(r.rdb$system_flag, 0) = 0
            and r.rdb$view_blr is null
        order by 1
    into :tname do
	begin
		stm = 'select count(*) from "' || tname || '"';
		execute statement :stm into :cnt;

		if (cnt > 0) then suspend;
	end
end
