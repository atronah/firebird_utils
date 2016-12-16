set term ^ ;

-- Выводит все дочерние элементы для указанного current_id или для всех элементов таблицы
create or alter procedure mds_get_children(
	table_name ttext32 -- имя таблицы, по которой производится поиск
	, id_field ttext32 -- имя поля с идентификатором элементов
	, parent_field ttext32 -- имя поле с идентификатором родительского элемента
	, current_id bigint = null -- идентификатор элемента, для которого необходимо найти дочерние (если пустой, то поиск дочерних будет для всех элементов таблицы)
	, only_leaf smallint = 0 -- выводить в результат только конечные\листовые элементы (у которых нет дочерних)
	, base_level smallint = 0 -- номер базового уровня, от которого отсчитывать номер дочернего уровня.
)
returns (
	id bigint -- идентификатор элемента
	, parent_id bigint -- идентификатор родительского элемента
	, child_level smallint -- уровень текущего элемента относительно базового
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
		-- если выводить все узлы (не только конечные), то вывести текущий
		if (only_leaf = 0) then suspend;
		
		has_child = 0;
		-- перебрать всех детей
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
		-- если выводить только конечные узлы, то вывести текущий лишь в случае отсутствия детей
		if (only_leaf > 0 and has_child = 0) then suspend;
	end
end^

set term ; ^