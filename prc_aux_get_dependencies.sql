set term ^ ;

create or alter procedure aux_get_dependencies(
    objects_to_process varchar(32000)
    , objects_to_exclude_regex varchar(32000) = null
    , types_to_exclude varchar(255) = null
    , max_depth smallint = null
)
returns(
    object_name varchar(255)
    , object_column varchar(255)
    , object_type type of column rdb$dependencies.rdb$dependent_type
    , object_type_name varchar(16)
    , depth smallint
)
as
declare object_full_name varchar(255);
declare object_type_filter type of column rdb$dependencies.rdb$dependent_type;
declare next_objects_to_process varchar(32000);
declare processed_objects varchar(32000);
declare required_object_name varchar(255);
declare required_object_column varchar(255);
declare required_object_type type of column rdb$dependencies.rdb$depended_on_type;
declare TYPE_TABLE type of column rdb$dependencies.rdb$dependent_type = 0;
declare TYPE_TABLE_NAME varchar(16) = 'table';
declare TYPE_VIEW type of column rdb$dependencies.rdb$dependent_type = 1;
declare TYPE_VIEW_NAME varchar(16) = 'view';
declare TYPE_TRIGGER type of column rdb$dependencies.rdb$dependent_type = 2;
declare TYPE_TRIGGER_NAME varchar(16) = 'trigger';
declare TYPE_PROCEDURE type of column rdb$dependencies.rdb$dependent_type = 5;
declare TYPE_PROCEDURE_NAME varchar(16) = 'procedure';
declare TYPE_PROCEDURE_PARAM_NAME varchar(16) = 'parameter';
declare TYPE_EXCEPTION type of column rdb$dependencies.rdb$dependent_type = 7;
declare TYPE_EXCEPTION_NAME varchar(16) = 'exception';
declare TYPE_COLUMN type of column rdb$dependencies.rdb$dependent_type = 0;
declare TYPE_COLUMN_NAME varchar(16) = 'column';
declare TYPE_SEQUENCE type of column rdb$dependencies.rdb$dependent_type = 14;
declare TYPE_SEQUENCE_NAME varchar(16) = 'sequence';
declare TYPE_DOMAIN type of column rdb$dependencies.rdb$dependent_type = 9;
declare TYPE_DOMAIN_NAME varchar(16) = 'domain';
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    max_depth = coalesce(max_depth, 100);
    objects_to_exclude_regex = coalesce(objects_to_exclude_regex, '');

    depth = 0;

    objects_to_process = trim(coalesce(objects_to_process, ''));
    next_objects_to_process = '';
    processed_objects = '';

    types_to_exclude = (select
                            list(distinct decode(lower(trim(part))
                                                , :TYPE_TABLE_NAME, :TYPE_TABLE
                                                , :TYPE_VIEW_NAME, :TYPE_VIEW
                                                , :TYPE_TRIGGER_NAME, :TYPE_TRIGGER
                                                , :TYPE_PROCEDURE_PARAM_NAME, :TYPE_PROCEDURE
                                                , :TYPE_PROCEDURE_NAME, :TYPE_PROCEDURE
                                                , :TYPE_EXCEPTION_NAME, :TYPE_EXCEPTION
                                                , :TYPE_COLUMN_NAME, :TYPE_COLUMN
                                                , :TYPE_SEQUENCE_NAME, :TYPE_SEQUENCE
                                                , :TYPE_DOMAIN_NAME, :TYPE_DOMAIN
                                                , lower(trim(part))))
                        from aux_split_text(:types_to_exclude));
    types_to_exclude = coalesce(types_to_exclude, '');

    while (objects_to_process > '' and depth <= max_depth) do
    begin
        for select distinct
                iif(part containing '.'
                    , substring(part from 1 for position('.' in part) - 1)
                    , part
                ) as object_name
                , iif(part containing '.'
                    , substring(part from position('.' in part) + 1)
                    , null
                ) as object_column
            from aux_split_text(:objects_to_process, ',')
            where trim(part) not similar to :objects_to_exclude_regex
                and (',' || :processed_objects || ',') not like ('%,' || hash(upper(trim(part))) || ',%')
            into object_name, object_column
        do
        begin
            object_name = upper(trim(object_name));
            object_column = upper(trim(object_column));
            object_type_filter = null;
            object_type = null;
            object_type_name = null;

            if (object_name containing ':') then
            begin
                object_type_filter = substring(object_name from 1 for position(':' in object_name) - 1);
                object_name = substring(object_name from position(':' in object_name) + 1);
            end

            for with info as (
                    select
                        :TYPE_PROCEDURE as object_type
                        , iif(nullif(:object_column, '') is null
                                , :TYPE_PROCEDURE_NAME
                                , :TYPE_PROCEDURE_PARAM_NAME
                        ) as object_type_name
                    from rdb$procedures
                    where rdb$procedure_name = upper(trim(:object_name))
                        and coalesce(rdb$system_flag, 0) = 0
                    union
                    select
                        :TYPE_TRIGGER as object_type, :TYPE_TRIGGER_NAME as object_type_name
                    from rdb$triggers
                    where rdb$trigger_name = upper(trim(:object_name))
                        and coalesce(rdb$system_flag, 0) = 0
                    union
                    select
                        :TYPE_COLUMN as object_type, :TYPE_COLUMN_NAME as object_type_name
                    from rdb$relation_fields
                    where rdb$relation_name = upper(trim(:object_name))
                        and rdb$field_name = upper(trim(:object_column))
                        and coalesce(rdb$system_flag, 0) = 0
                    union
                    select
                        iif(rdb$relation_type = 1, :TYPE_VIEW, :TYPE_TABLE) as object_type
                        , iif(rdb$relation_type = 1, :TYPE_VIEW_NAME, :TYPE_TABLE_NAME) as object_type_name
                    from rdb$relations
                    where nullif(:object_column, '') is null
                        and rdb$relation_name = upper(trim(:object_name))
                        and coalesce(rdb$system_flag, 0) = 0
                    union
                    select
                        :TYPE_EXCEPTION as object_type, :TYPE_EXCEPTION_NAME as object_type_name
                    from rdb$exceptions
                    where rdb$exception_name = upper(trim(:object_name))
                        and coalesce(rdb$system_flag, 0) = 0
                    union
                    select
                        :TYPE_DOMAIN as object_type, :TYPE_DOMAIN_NAME as object_type_name
                    from rdb$fields
                    where rdb$field_name = upper(trim(:object_name))
                        and coalesce(rdb$system_flag, 0) = 0
                    union
                    select
                        :TYPE_SEQUENCE as object_type, :TYPE_SEQUENCE_NAME as object_type_name
                    from rdb$generators
                    where rdb$generator_name = upper(trim(:object_name))
                        and coalesce(rdb$system_flag, 0) = 0
                )
                select
                    info.object_type, trim(info.object_type_name)
                from info
                where info.object_type = coalesce(:object_type_filter, info.object_type)
                into object_type, object_type_name
            do
            begin
                object_full_name = trim(object_type || ':'
                                        || object_name
                                        || coalesce('.' || object_column, ''));
                if ((',' || :processed_objects || ',') not like ('%,' || hash(object_full_name) || ',%'))
                    then processed_objects = processed_objects || ',' || hash(object_full_name);

                suspend;

                -- get list of db objects, which required for current object (with :object_name and :object_type)
                for -- general dependencies
                    select
                        rdb$depended_on_name as required_object_name
                        , rdb$field_name as required_object_column
                        , rdb$depended_on_type as required_object_type
                    from rdb$dependencies
                    where rdb$dependent_name = :object_name
                        and rdb$dependent_type = :object_type
                        and trim(rdb$depended_on_name) || trim(coalesce('.' || trim(rdb$field_name), '')) not similar to :objects_to_exclude_regex
                        and (',' || :processed_objects || ',')
                                not like ('%,' || hash(rdb$depended_on_type || ':'
                                                        || upper(trim(rdb$depended_on_name)
                                                        || trim(coalesce('.' || trim(rdb$field_name), '')))) || ',%')
                        and (',' || :types_to_exclude || ',') not like ('%,' || rdb$depended_on_type || ',%')
                    union
                    -- all domains used for table columns
                    select
                        rdb$field_source as required_object_name
                        , null as required_object_column
                        , :TYPE_DOMAIN as required_object_type
                    from rdb$relation_fields
                    where rdb$relation_name = upper(trim(:object_name))
                        and :object_type = :TYPE_TABLE
                        and rdb$field_name = upper(trim(coalesce(:object_column, rdb$field_name)))
                        and rdb$field_source not starts with 'RDB$'
                        and trim(rdb$relation_name) not similar to :objects_to_exclude_regex
                        and (',' || :processed_objects || ',')
                                not like ('%,' || hash(upper(trim(:TYPE_DOMAIN || ':' || rdb$field_source))) || ',%')
                        and (',' || :types_to_exclude || ',') not like ('%,' || :TYPE_DOMAIN || ',%')
                    into required_object_name, required_object_column, required_object_type
                do
                begin
                    required_object_name = upper(trim(required_object_name));
                    required_object_column = upper(trim(required_object_column));

                    object_full_name =  trim(required_object_type || ':'
                                            || required_object_name
                                            || coalesce('.' || required_object_column, ''));
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

