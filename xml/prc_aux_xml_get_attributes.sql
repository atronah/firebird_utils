set term ^ ;

-- Parses all attributes from text
create or alter procedure aux_xml_get_attributes(
    xml_openning_tag blob sub_type text
)
returns(
    alias varchar(1024)
    , name varchar(1024)
    , val varchar(16000)
    --
    , name_pattern varchar(1024)
    , aliased_name_pattern varchar(1024)
    , attribute_pattern varchar(1024)
    , attribute_list_pattern varchar(1024)
)
as
declare attributes tblob;
declare pos bigint;
declare len bigint;
declare c varchar(1);
declare state smallint;
-- Constants
declare STATE_NONE smallint = 0;
declare STATE_NAME smallint = 1;
declare STATE_WS_BEFORE_EQUAL smallint = 2;
declare STATE_EQUAL smallint = 3;
declare STATE_WS_AFTER_EQUAL smallint = 1;
declare STATE_VALUE smallint = 5;
declare STATE_UNEXPECTED smallint = 6;
begin
    -- create exception ERROR 'ERROR';

    name_pattern = '[a-zA-Zа-яА-ЯёЁ][a-zA-Zа-яА-ЯёЁ0-9_]*'; -- name pattern
    aliased_name_pattern = '(' || :name_pattern || ':)*' || :name_pattern; -- aliased name pattern
    attribute_pattern = :aliased_name_pattern || '\s*=\s*"[^"]*"'; -- attribute pattern
    attribute_list_pattern = '(\s*' || :attribute_pattern || ')+'; -- attributes pattern

    attributes = (select trim(match) from mds_aux_regexp_search(:attribute_list_pattern, :xml_openning_tag, 1));

    pos = 0;
    state = STATE_NONE;

    len = char_length(attributes);
    while (pos < len) do
    begin
        pos = pos + 1;
        c = substring( from pos for 1);

        state = case state
                    when STATE_NONE
                        then iif(c is distinct from ' ', STATE_UNEXPECTED, state)
                    when STATE_ALIAS
                        then STATE_UNEXPECTED
                    when STATE_NAME
                        then decode(c, ' ', STATE_WS_BEFORE_EQUAL
                                    , '=', STATE_EQUAL
                                    , ':', STATE_ALIAS
                                    , state)
                    when STATE_EQUAL, STATE_WS_AFTER_EQUAL
                            , STATE_VALUE, STATE_VALUE
                            , STATE_UNEXPECTED);
                    else STATE_UNEXPECTED;
                end;

        if (state = STATE_ALIAS) then
        begin
            if (alias is null) then
            begin
                alias = name;
                name = null;
                state = STATE_NAME;
            end
            else state = STATE_UNEXPECTED;
        end

        if (state = STATE_UNEXPECTED)
            then exception ERROR 'parsing error: unexpected character ' || coalesce(c, 'null')
                                        || ' at position ' || coalesce(pos, 'null');

        if (c = ' ') then
        begin

        end
        else if (c = '=') then
        begin
            state = decode(state
                            , STATE_NAME, STATE_EQUAL
                            , STATE_WS_BEFORE_EQUAL, STATE_EQUAL
                            , STATE_VALUE, STATE_VALUE
                            , STATE_UNEXPECTED);
        end
        else if (c = '=') then
        begin
            state = decode(state
                            , STATE_NAME, STATE_EQUAL
                            , STATE_WS_BEFORE_EQUAL, STATE_EQUAL
                            , STATE_VALUE, STATE_VALUE
                            , STATE_UNEXPECTED);
        end



            if (state in (STATE_NAME, STATE_WHITESPACE))
                then state = STATE_EQ;
            else if (state is distinct from STATE_VALUE)
                then exception ERROR 'parsing error: unexpected character ' || coalesce('"' || c || '"', 'null')
                                        || ' at position ' || coalesce(pos, 'null');
        end
        else if (c = ':') then
        begin
            if (state in (STATE_NAME) and alias is null) then
            begin
                alias = name;
                name = null;
                continue;
            end else if (state is distinct from STATE_VALUE)
                then exception ERROR 'parsing error: unexpected character ' || coalesce(c, 'null')
                                        || ' at position ' || coalesce(pos, 'null');
        end
        else if (c = '"') then
        begin
            if (state in (STATE_NAME) and alias is null) then
            begin
                alias = name;
                name = null;
                continue;
            end else if (state is distinct from STATE_VALUE)
                then
        end
    end




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
