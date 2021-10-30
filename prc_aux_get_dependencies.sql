set term ^ ;

create or alter procedure aux_get_dependencies(
    objects_to_process varchar(16384)
    , objects_to_exclude_regex varchar(32000) = null
    , types_to_exclude varchar(255) = null
    , max_depth smallint = null
)
returns(
    object_name type of column rdb$dependencies.rdb$dependent_name
    , object_column type of column rdb$dependencies.rdb$field_name
    , object_type type of column rdb$dependencies.rdb$dependent_type
    , object_type_name varchar(16)
    , depth smallint
)
as
declare object_full_name varchar(255);
declare next_objects_to_process varchar(32000);
declare processed_objects varchar(32000);
declare required_object_name type of column rdb$dependencies.rdb$depended_on_name;
declare required_object_column type of column rdb$dependencies.rdb$field_name;
declare required_object_type type of column rdb$dependencies.rdb$depended_on_type;
declare TYPE_TABLE type of column rdb$dependencies.rdb$dependent_type = 0;
declare TYPE_VIEW type of column rdb$dependencies.rdb$dependent_type = 1;
declare TYPE_TRIGGER type of column rdb$dependencies.rdb$dependent_type = 2;
declare TYPE_PROCEDURE type of column rdb$dependencies.rdb$dependent_type = 5;
declare TYPE_EXCEPTION type of column rdb$dependencies.rdb$dependent_type = 7;
declare TYPE_COLUMN type of column rdb$dependencies.rdb$dependent_type = 9;
declare TYPE_SEQUENCE type of column rdb$dependencies.rdb$dependent_type = 14;
declare TYPE_DOMAIN type of column rdb$dependencies.rdb$dependent_type = -1;
begin
    max_depth = coalesce(max_depth, 100);
    objects_to_exclude_regex = coalesce(objects_to_exclude_regex, '');

    depth = 0;

    objects_to_process = trim(coalesce(objects_to_process, ''));
    next_objects_to_process = '';
    processed_objects = '';

    types_to_exclude = (select
                            list(distinct decode(lower(trim(part))
                                                , 'table', :TYPE_TABLE
                                                , 'view', :TYPE_VIEW
                                                , 'trigger', :TYPE_TRIGGER
                                                , 'procedure param', :TYPE_PROCEDURE
                                                , 'procedure', :TYPE_PROCEDURE
                                                , 'exception', :TYPE_EXCEPTION
                                                , 'column', :TYPE_COLUMN
                                                , 'sequence', :TYPE_SEQUENCE
                                                , 'domain', :TYPE_DOMAIN
                                                , lower(trim(part))))
                        from aux_split_text(:types_to_exclude));
    types_to_exclude = coalesce(types_to_exclude, '');

    while (objects_to_process > '' and depth <= max_depth) do
    begin
        for select distinct
                iif(part containing '.'
                    , substring(part from 1 for position('.' in part) - 1)
                    , part) as object_name
                , iif(part containing '.'
                    , substring(part from position('.' in part) + 1)
                    , null) as object_column
            from aux_split_text(:objects_to_process, ',')
            where trim(part) not similar to :objects_to_exclude_regex
                and (',' || :processed_objects || ',') not like ('%,' || hash(upper(trim(part))) || ',%')
            into object_name, object_column
        do
        begin
            object_type = null;
            object_type_name = null;

            with info as (
                select
                    :TYPE_PROCEDURE as object_type
                from rdb$procedures
                where rdb$procedure_name = upper(trim(:object_name))
                    and coalesce(rdb$system_flag, 0) = 0
                union
                select
                    :TYPE_TRIGGER as object_type
                from rdb$triggers
                where rdb$trigger_name = upper(trim(:object_name))
                    and coalesce(rdb$system_flag, 0) = 0
                union
                select
                    :TYPE_COLUMN as object_type
                from rdb$relation_fields
                where rdb$relation_name = upper(trim(:object_name))
                    and rdb$field_name = upper(trim(:object_column))
                    and coalesce(rdb$system_flag, 0) = 0
                union
                select
                    decode(rdb$relation_type
                            , 1, :TYPE_VIEW
                            , :TYPE_TABLE
                    ) as object_type
                from rdb$relations
                where nullif(:object_column, '') is null
                    and rdb$relation_name = upper(trim(:object_name))
                    and coalesce(rdb$system_flag, 0) = 0
                union
                select
                    :TYPE_EXCEPTION as object_type
                from rdb$exceptions
                where rdb$exception_name = upper(trim(:object_name))
                    and coalesce(rdb$system_flag, 0) = 0
                union
                select
                    :TYPE_DOMAIN as object_type
                from rdb$fields
                where rdb$field_name = upper(trim(:object_name))
                    and coalesce(rdb$system_flag, 0) = 0
                union
                select
                    :TYPE_SEQUENCE as object_type
                from rdb$generators
                where rdb$generator_name = upper(trim(:object_name))
                    and coalesce(rdb$system_flag, 0) = 0
            )
            select object_type
                from info
                into object_type;

            if (object_type is not null) then
            begin
                object_type_name = trim(decode(object_type
                                            , :TYPE_TABLE, 'table'
                                            , :TYPE_VIEW, 'view'
                                            , :TYPE_TRIGGER, 'trigger'
                                            , :TYPE_PROCEDURE, iif(object_column is not null
                                                                    , 'procedure param'
                                                                    , 'procedure')
                                            , :TYPE_EXCEPTION, 'exception'
                                            , :TYPE_COLUMN, 'column'
                                            , :TYPE_SEQUENCE, 'sequence'
                                            , :TYPE_DOMAIN, 'domain'
                                            , 'unknown(' || object_type || ')'
                                        )
                                    );

                object_full_name = upper(trim(object_name)
                                        || trim(coalesce('.' || trim(object_column), '')));
                if ((',' || :processed_objects || ',') not like ('%,' || hash(object_full_name) || ',%'))
                    then processed_objects = processed_objects || ',' || hash(object_full_name);

                suspend;

                for select
                        rdb$depended_on_name as required_object_name
                        , rdb$field_name as required_object_column
                        , rdb$depended_on_type as required_object_type
                    from rdb$dependencies
                    where rdb$dependent_name = upper(trim(:object_name))
                        and trim(rdb$depended_on_name) || trim(coalesce('.' || trim(rdb$field_name), '')) not similar to :objects_to_exclude_regex
                        and (',' || :processed_objects || ',') not like ('%,' || hash(upper(trim(rdb$depended_on_name) || trim(coalesce('.' || trim(rdb$field_name), '')))) || ',%')
                        and (',' || :types_to_exclude || ',') not like ('%,' || rdb$depended_on_type || ',%')
                    union
                    select
                        rdb$field_source as required_object_name
                        , null as required_object_column
                        , :TYPE_DOMAIN as required_object_type
                    from rdb$relation_fields
                    where rdb$relation_name = upper(trim(:object_name))
                        and rdb$field_name = upper(trim(coalesce(:object_column, rdb$field_name)))
                        and rdb$field_source not starts with 'RDB$'
                        and trim(rdb$relation_name) not similar to :objects_to_exclude_regex
                        and (',' || :processed_objects || ',') not like ('%,' || hash(upper(trim(rdb$field_source))) || ',%')
                        and (',' || :types_to_exclude || ',') not like ('%,' || :TYPE_DOMAIN || ',%')
                    into required_object_name, required_object_column, required_object_type
                do
                begin
                    object_full_name = upper(trim(required_object_name)
                                            || trim(coalesce('.' || trim(required_object_column), '')));
                    if ((',' || next_objects_to_process || ',') not like ('%,' || object_full_name || ',%')) then
                    begin
                        next_objects_to_process = next_objects_to_process || ',' || object_full_name;
                    end
                end
            end
        end

        objects_to_process = next_objects_to_process;
        next_objects_to_process = '';

        depth = depth + 1;
    end
end^

set term ; ^

comment on procedure aux_get_dependencies is 'Returns all dependencies for specified in first argument db objects,
i.e. all db objects which are requeired for creating objects from first arguemnt.';

-- input parameters
comment on parameter aux_get_dependencies.objects_to_exclude_regex is 'Regular expression (like for `similar to` statement) for names of ignored objects';
comment on parameter aux_get_dependencies.types_to_exclude is 'List of ignored types of objects.
Comma separated names or integer values corresponding to values of field RDB$DEPENDENCIES.RDB$DEPENDED_ON_TYPE from list bellow:
- `table` or `0` - table
- `view` or `1`
- `trigger` or `2`
- `3` - computed column
- `4` - CHECK constraint
- `procedure param` or `procedure` or `5`
- `exception` or `7`
- `8` - user
- `column` or `9`
- `10` - index
- `sequence` or `14`
- `15` - UDF
- `17` - collation
';
comment on parameter aux_get_dependencies.max_depth is 'Maximum depth of dependencies tree; default is 100';

-- output parameters
comment on parameter aux_get_dependencies.object_name is 'Name of required object';
comment on parameter aux_get_dependencies.object_column is 'Name of required column';
comment on parameter aux_get_dependencies.object_type is 'Type of required object
(based on values of RDB$DEPENDENCIES.RDB$DEPENDED_ON_TYPE):
- -1 - domain
- 0 - table
- 1 - view
- 2 - trigger
- 5 - procedure
- 7 - exception
- 9 - column
- 14 - sequence
';
comment on parameter aux_get_dependencies.object_type_name is 'Name of required object';

