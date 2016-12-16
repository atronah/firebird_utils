set term ^ ;

-- Returns all child items of specified item with current_id (or each item of table)
create or alter procedure mds_get_children(
	table_name ttext32 -- name of table in which the items are searched
	, id_field ttext32 -- name of table field, wherein the item identifier is stored
	, parent_field ttext32 -- name of table field, wherein the parent item identifier is stored
	, current_id bigint = null -- current item identifier, for which children are searched (if null - childrean are searched for each element of table)
	, only_leaf smallint = 0 -- 0 - returns all results, 1 - returns only leaf items (without children)
	, base_level smallint = 0 -- number of base level which is considered relatively child level number
)
returns (
	id bigint -- item identified
	, parent_id bigint -- parent item identified
	, child_level smallint -- child level number
)
as 
declare stmt tblob;
declare has_child smallint;
begin
	child_level = base_level;
	stmt = '
			select  
				' || :id_field || ' as id,  
				' || :parent_field || ' as parent_id
			from ' || :table_name;
	
	if (current_id is not null)
		then stmt = stmt || '
			where ' || :parent_field || ' = ' || :current_id; 

	
	for execute statement stmt
	into :id, :parent_id do 
	begin
		if (only_leaf = 0) then suspend;
		
		has_child = 0;
		
		for select id, parent_id, child_level 
			from mds_get_children(:table_name
									, :id_field
									, :parent_field
									, :id
									, :only_leaf
									, :base_level + 1)
			into :id, :parent_id, :child_level do
			begin
				has_child = 1;
				suspend;
			end
		if (only_leaf <> 0 and has_child = 0) then suspend;
	end
end^

set term ; ^