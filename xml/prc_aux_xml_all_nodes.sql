set term ^ ;

-- creates dummy procedure to prevent errors because of changed input params for recursive procedure
create or alter procedure aux_xml_all_nodes(
    xml blob sub_type text
    , root_path blob sub_type text = null
    , root_level smallint = null
)
returns(
    path blob sub_type text,
    ns_uri varchar(1024),
    ns_alias varchar(1024),
    name varchar(1024),
    content blob sub_type text,
    attributes blob sub_type text,
    startpos bigint,
    endpos bigint,
    level smallint
)
as
begin
end^


-- Parse XML and returns all nodes of it with its pathes and content
create or alter procedure aux_xml_all_nodes(
    xml blob sub_type text
    , root_path blob sub_type text = null
    , root_level smallint = null
)
returns(
    path blob sub_type text,
    ns_uri varchar(1024),
    ns_alias varchar(1024),
    name varchar(1024),
    content blob sub_type text,
    attributes blob sub_type text,
    startpos bigint,
    endpos bigint,
    level smallint
)
as
declare fullname varchar(1024);
declare name_pattern varchar(1024);
declare aliased_name_pattern varchar(1024);
declare attribute_pattern varchar(1024);
declare attribute_list_pattern varchar(1024);
declare otp varchar(1024);
declare open_tag varchar(4096);
declare next_similar bigint;
declare next_similar_with_attrs bigint;
declare nested_level bigint;
declare saved_startpos bigint;
declare saved_endpos bigint;
declare content_offset bigint;
-- Constants
declare NESTED_LIMIT smallint = 100;
declare ENDL varchar(2) = '
';
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    -- create exception ERROR 'ERROR';

    root_path = coalesce(trim(root_path), '');
    if (root_path not starts with '/') then
        root_path = '/' || root_path;

    path = trim(root_path);
    if (right(path, 1) = '/' and path <> '/')
        then path = substring(path from 1 for char_length(path) - 1);

    root_level = coalesce(root_level, 0);
    level = root_level;

    name = '';
    ns_alias = '';
    content_offset = 0;

    name_pattern = '[a-zA-Zа-яА-ЯёЁ][a-zA-Zа-яА-ЯёЁ0-9_\.]*'; -- name pattern
    aliased_name_pattern = '(' || :name_pattern || ':)*' || :name_pattern; -- aliased name pattern
    attribute_pattern = :aliased_name_pattern || '\s*=\s*"[^"]*"'; -- attribute pattern
    attribute_list_pattern = '(\s*' || :attribute_pattern || ')+'; -- attributes pattern
    otp = '<' || :aliased_name_pattern || '(\s+' || :attribute_pattern || ')*\s*/?>'; -- open tag pattern

    startpos = position('<', xml);
    while (startpos > 0) do
    begin
        -- returns `<my_node>` for `  <my_node></my_node>`
        -- returns `<my_node />` for `  <my_node /><a></a>`
        open_tag = (select match
                        from mds_aux_regexp_search(:otp
                                                , substring(:xml from :startpos
                                                                 for maxvalue(position('>', :xml, :startpos) - :startpos + 1, 0))
                                                    , 1));
        if(open_tag is not null) then
        begin
            endpos = startpos + char_length(open_tag) - 1; -- position of `>` for open tag
            -- returns `ns:name` for `<ns:name a="x">`
            fullname = (select substring(match from 2) from mds_aux_regexp_search('<' || :aliased_name_pattern, :open_tag, 1));
            attributes = (select trim(match) from mds_aux_regexp_search(:attribute_list_pattern, :open_tag, 1));
            name = substring(fullname from maxvalue(position(':' in fullname) + 1, 0));
            ns_alias = substring(fullname from 1 for maxvalue(position(name in fullname) - 2, 0));

            if(right(open_tag, 2) <> '/>') then
            begin
                nested_level = 0;
                -- position of the nearest close tag for non-empty node with the same name
                endpos = position('</' || fullname || '>', xml, endpos);
                -- get position of the next nearest node with the same name
                next_similar = startpos;
                next_similar = position('<' || :fullname || '>', xml, next_similar + 1);
                next_similar_with_attrs = position('<' || :fullname || ' ', xml, next_similar + 1);
                if (next_similar_with_attrs > 0 and next_similar_with_attrs < next_similar)
                    then next_similar = next_similar_with_attrs;
                -- skip nested nodes with the same name
                while ((next_similar between startpos and endpos
                            or nested_level > 0)
                        and nested_level < NESTED_LIMIT
                ) do
                begin
                    if (next_similar between startpos and endpos) then
                    begin
                        nested_level = nested_level + 1;
                    end
                    else
                    begin
                        nested_level = nested_level - 1;
                        next_similar = endpos;
                        endpos = position('</' || fullname || '>', xml, endpos + 1);
                    end

                    next_similar = position('<' || :fullname || '>', xml, maxvalue(next_similar, startpos) + 1);
                    next_similar_with_attrs = position('<' || :fullname || ' ', xml, maxvalue(next_similar, startpos) + 1);
                    if (next_similar_with_attrs > 0 and next_similar_with_attrs < next_similar)
                        then next_similar = next_similar_with_attrs;
                end

                content_offset = startpos + char_length(open_tag);
                content = substring(xml from content_offset
                                        for maxvalue(endpos - startpos - char_length(open_tag), 0));
                endpos = endpos + char_length('</' || fullname || '>') - 1;
            end
            else
            begin
                content = '';
            end
            if (endpos < startpos)
                then exception ERROR 'parsing error: for node ' || coalesce('<' || fullname || '>', 'null')
                                        || ' end tag found at position ' || coalesce(endpos, 'null')
                                        || ' that''s before start tag position' || coalesce(startpos, 'null');
            suspend;

            saved_startpos = startpos;
            saved_endpos = endpos;

            for select path, ns_uri, ns_alias, name, content, attributes, startpos, endpos, level
                from aux_xml_all_nodes(:content
                                        , :root_path || trim(iif(:root_path <> '/', '/', '')) || :name
                                        , :level + 1)
                into path, ns_uri, ns_alias, name, content, attributes, startpos, endpos, level
            do
            begin
                startpos = content_offset + startpos - 1;
                endpos = content_offset + endpos - 1;
                suspend;
            end
            path = root_path;
            level = root_level;
            startpos = saved_startpos;
            endpos = saved_endpos;
        end
        else endpos = startpos;

        startpos = position('<', xml, endpos + 1);
    end
end^

set term ; ^


comment on procedure aux_xml_all_nodes is 'Parse XML and returns all nodes of it with its pathes and content';
comment on parameter aux_xml_all_nodes.xml is 'XML data to parse';
comment on parameter aux_xml_all_nodes.root_path is 'Service input param to pass path in recursive call';
comment on parameter aux_xml_all_nodes.root_level is 'Service input param to pass level path in recursive call';
comment on parameter aux_xml_all_nodes.path is 'Path of XML node (`/` for root). Always starts with `/` and do NOT contain `/` at the end';
comment on parameter aux_xml_all_nodes.ns_uri is 'URI of namespace, declared within node (not yet implemented)';
comment on parameter aux_xml_all_nodes.ns_alias is 'Alias of node name';
comment on parameter aux_xml_all_nodes.name is 'Name of XML node';
comment on parameter aux_xml_all_nodes.content is 'Content of XML node';
comment on parameter aux_xml_all_nodes.attributes is 'Attributes of XML node';
comment on parameter aux_xml_all_nodes.startpos is 'Starting position of XML node (position of `<` in openning tag)';
comment on parameter aux_xml_all_nodes.endpos is 'Ending position of XML node (position of `>` in closing tag)';
comment on parameter aux_xml_all_nodes.level is 'Hierarchy level of XML node (root has 0 and its chidren has 1, etc.)';
