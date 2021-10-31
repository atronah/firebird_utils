set term ^ ;

create or alter procedure aux_get_procedures_order(
    procedures_list varchar(16384)
    , sub_call smallint = null
)
returns(
    create_order bigint
    , procedure_name varchar(31)
    , required_procedures varchar(32000)
    , required_procedures_count bigint
    , loop_type smallint
)
as
declare depth smallint;
declare new_required_procedures varchar(32000);
declare new_required_procedures_count bigint;
declare processed_procedures varchar(16384);
declare deferred_procedures_list varchar(16384);
declare max_depth smallint = 100;
declare TYPE_PROCEDURE type of column rdb$dependencies.rdb$dependent_type = 5;
declare NO_LOOP smallint = 0;
declare LOOP_DIRECTLY smallint = 1;
declare LOOP_THROUGH_OTHER smallint = 2;
begin
    if (coalesce(sub_call, 0) > 0) then
    begin
        create_order = 0;
        for select distinct
                upper(trim(part))
            from aux_split_text(:procedures_list, ',')
            where coalesce(upper(trim(part)), '') > ''
            into procedure_name
        do
        begin
            required_procedures = procedure_name; required_procedures_count = 0;
            new_required_procedures_count = null;

            depth = 0;
            while (new_required_procedures_count is distinct from required_procedures_count
                    and depth < max_depth
            ) do
            begin
                select
                        list(distinct upper(trim(rdb$depended_on_name)))
                        , count(distinct upper(trim(rdb$depended_on_name)))
                    from rdb$dependencies
                    where rdb$depended_on_type = :TYPE_PROCEDURE
                        and (',' || :required_procedures || ',') like ('%,' || upper(trim(rdb$dependent_name)) || ',%')
                        and (',' || :required_procedures || ',') not like ('%,' || upper(trim(rdb$depended_on_name)) || ',%')
                    into new_required_procedures, new_required_procedures_count;
                if (new_required_procedures_count is distinct from required_procedures_count) then
                begin
                    required_procedures = new_required_procedures;
                    required_procedures_count = new_required_procedures_count;
                end
                depth = depth + 1;
            end

            loop_type = NO_LOOP;

            if (exists(select rdb$depended_on_name
                                    from rdb$dependencies
                                    where rdb$depended_on_type = :TYPE_PROCEDURE
                                        and rdb$dependent_name = :procedure_name
                                        and upper(trim(rdb$depended_on_name)) = :procedure_name
                )
            ) then loop_type = loop_type + :LOOP_DIRECTLY;

            if (exists(select rdb$depended_on_name
                        from rdb$dependencies
                        where rdb$depended_on_type = :TYPE_PROCEDURE
                            and (',' || :required_procedures || ',') like ('%,' || upper(trim(rdb$dependent_name)) || ',%')
                            and upper(trim(rdb$depended_on_name)) = :procedure_name
                )
            ) then loop_type = loop_type + :LOOP_THROUGH_OTHER;

            if (loop_type > 0) then required_procedures = procedure_name || ',' || required_procedures;

            suspend;
        end
    end
    else
    begin
        depth = 0;
        create_order = 0;
        processed_procedures = '';
        while (coalesce(procedures_list, '') > '' and depth < max_depth) do
        begin
            deferred_procedures_list = '';
            for select
                    procedure_name, required_procedures, required_procedures_count, loop_type
                from aux_get_procedures_order(:procedures_list, 1)
                order by required_procedures_count asc, procedure_name asc
                into procedure_name, required_procedures, required_procedures_count, loop_type
            do
            begin
                if (required_procedures_count = 0 -- no required procedures
                    -- or all required procedures was processed
                    or not exists(select idx
                                    from aux_split_text(:required_procedures, ',') as req_p
                                    where upper(trim(req_p.part)) not in (select
                                                                                upper(trim(proc_p.part))
                                                                            from aux_split_text(:processed_procedures, ',') as proc_p
                                                                        )
                    )
                    -- or all required procedures was processed except current procedure which uses itself directly
                    or bin_and(loop_type, :LOOP_DIRECTLY) > 0
                        and (select list(distinct upper(trim(req_p.part)))
                            from aux_split_text(:required_procedures, ',') as req_p
                            where upper(trim(req_p.part)) not in (select
                                                                        upper(trim(proc_p.part))
                                                                    from aux_split_text(:processed_procedures, ',') as proc_p
                                                                )
                        ) = :procedure_name
                ) then
                begin
                    processed_procedures = processed_procedures || ',' || procedure_name;
                    create_order = create_order + 1;
                    suspend;
                end
                else
                begin
                    if (bin_and(loop_type, :LOOP_THROUGH_OTHER) > 0) then
                    begin
                        processed_procedures = processed_procedures || ',' || procedure_name;
                        suspend;
                    end
                    deferred_procedures_list = deferred_procedures_list || ',' || procedure_name;
                end
            end
            if (deferred_procedures_list is not distinct from procedures_list)
                then break;
            procedures_list = deferred_procedures_list;
        end
    end
end^

set term ; ^

comment on procedure aux_get_procedures_order is 'Returns all passed procedures in order for creating.';

-- input parameters
comment on parameter aux_get_procedures_order.procedures_list is 'List of procedures to calculate creating order';
comment on parameter aux_get_procedures_order.sub_call is 'SSpecial argument for internal usage.';

-- output parameters
comment on parameter aux_get_procedures_order.create_order is 'Number of creating order';
comment on parameter aux_get_procedures_order.procedure_name is 'Name of procedure';
comment on parameter aux_get_procedures_order.required_procedures is 'List of required procedures';
comment on parameter aux_get_procedures_order.required_procedures_count is 'Count of required procedures';
comment on parameter aux_get_procedures_order.loop_type is 'Type of loop:
- 0 - procedure doesn''t calls itself
- 1 - procedure calls itself directly
- 2 - procedure calls itself through other procedure,
- 3 - both 1 and 2 (call itself directly and through other procedure' ;


