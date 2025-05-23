set term ^ ;

-- searches first match in text for passed regular expression pattern
create or alter procedure aux_regexp_search(
    pattern blob sub_type text
    , text blob sub_type text
    , syntax smallint = null
    , only_first smallint = null
)
returns(
    match blob sub_type text
    , startpos bigint
)
as
declare len bigint;
declare part blob sub_type text;
declare pos bigint;
declare endpos bigint;
declare dot varchar(1024);
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    syntax = coalesce(syntax, 0);
    only_first = coalesce(only_first, 1);
    startpos = null;
    pos = 1;
    endpos = 1;

    pattern = coalesce(pattern, '');
    if (pattern = '') then exit;

    if (syntax = 1) then
    begin
        part = '<double_slash>'; -- surrogate replacer to temporary replace back double slash symbol (`\\`) (after all other replaces it will be replaced to real `\\` - symbol)
        -- if pattern contain substring which equal surrogate replacer, change surrogate replacer to anonther (until success)
        while (position(part in pattern) > 0) do part = replace(part, '_', '__');

        pattern = replace(pattern, '\\', part);
        pattern = replace(pattern, '\s', '[[:WHITESPACE:]]');
        pattern = replace(pattern, '\S', '[^[:WHITESPACE:]]');
        pattern = replace(pattern, '\w', '[a-zA-Zа-яёА-ЯЁ0-9_]');
        pattern = replace(pattern, '\W', '[^a-zA-Zа-яёА-ЯЁ0-9_]');
        pattern = replace(pattern, '\d', '[0-9]');
        pattern = replace(pattern, '\D', '[^0-9]');

        dot = '<dot>'; -- surrogate replacer for dot (`.`) symbol
        -- if pattern contain substring which equal surrogate replacer, change surrogate replacer to anonther (until success)
        while (position(dot in pattern) > 0) do dot = replace(dot, '<', '<<');
        pattern = replace(pattern, '\.', dot);
        pattern = replace(pattern, '.', '_');
        pattern = replace(pattern, dot, '.');

        pattern = replace(pattern, part, trim('\ ')); -- trim('\ ') used instead '\', because '\' break syntax highlighting in notepad++
    end

    len = char_length(text);

    match = null;
    part = null;

    while (pos <= len) do
    begin
        part = substring(text from pos for endpos - pos + 1);
        if (part similar to pattern) then
        begin
            startpos = pos;
            match = part;
        end

        endpos = endpos + 1;
        if (endpos > len) then
        begin
            if(match is not null) then
            begin
                if (only_first > 0) then break;
                suspend;
                match = null;
            end
            pos = pos + 1;
            endpos = pos;
        end
    end

    if (only_first > 0 and match is not null) then suspend;
end^

set term ; ^

comment on procedure aux_regexp_search is 'searches first match in text for passed regular expression pattern';
comment on parameter aux_regexp_search.pattern is 'RegExp pattern';
comment on parameter aux_regexp_search.text is 'Text for search';
comment on parameter aux_regexp_search.syntax is 'Syntax of regular expression: 0 - firebird, 1 - common (partially supported)';
comment on parameter aux_regexp_search.only_first is 'Shows only first match (if above 0), otherwise shows all matches';
comment on parameter aux_regexp_search.match is 'First match';
comment on parameter aux_regexp_search.startpos is 'position of match in text';