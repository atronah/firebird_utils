set term ^ ;

create or alter procedure aux_strip_text(
    source_text varchar(4096)
    , symbols_list varchar(4096) = null
    , strip_rule smallint = null
    , substitute varchar(16) = null
)
returns(
    result varchar(4096)
    , affected_symbols smallint
)
as
declare len bigint;
declare pos bigint;
declare symbol varchar(1);
declare prev_symbol varchar(1);
-- Constants
-- -- Stripping rule (`strip_rule`)
declare REMOVE_GIVEN_SYMBOLS smallint = 0; -- 0 - removes from source text (`source_text`)  all symbols specified in `symbols_list`
declare REMOVE_ALL_EXCEPT_GIVEN_SYMBOLS smallint = 1; -- 1 - removes from source text (`source_text`) all symbols EXCEPT specified in `symbols_list`
declare REMOVE_REPEAT_OF_GIVEN_SYMBOLS smallint = 2; -- 2 - removes from source text (`source_text`) the second and subsequent repetitions of symbol from `symbols_list`
begin
    affected_symbols = 0;

    if (coalesce(source_text, '') > '') then
    begin
        result = '';

        symbols_list = coalesce(symbols_list, '');
        strip_rule = coalesce(strip_rule, 0);
        substitute = coalesce(substitute, '');

        len = char_length(source_text);
        pos = 1;

        while (pos <= len) do
        begin
            symbol = substring(source_text from pos for 1);
            if (strip_rule = REMOVE_GIVEN_SYMBOLS and position(symbol in symbols_list) > 0
                or strip_rule = REMOVE_ALL_EXCEPT_GIVEN_SYMBOLS and position(symbol in symbols_list) = 0
                or strip_rule = REMOVE_REPEAT_OF_GIVEN_SYMBOLS and position(symbol in symbols_list) > 0 and symbol = prev_symbol
            ) then
            begin
                result = result || substitute;
                affected_symbols = affected_symbols + 1;
            end
            else result = result || symbol;

            pos = pos + 1;
            prev_symbol = symbol;
        end
    end
    else result = source_text;

    suspend;
end^

set term ; ^

comment on procedure aux_strip_text is 'Strips/reduces input text (`source_text`) according to the given stripping rule (`strip_rule`)';
comment on parameter aux_strip_text.source_text is 'Source text to strip/reduce';
comment on parameter aux_strip_text.symbols_list is 'List of symbols required by stripping rule (`strip_rule`). Empty by default.';
comment on parameter aux_strip_text.strip_rule is 'Stripping rule:
- 0 (default) - removes from source text (`source_text`)  all symbols specified in `symbols_list` (`123qwe` + `123` -> `qwe`);
- 1 - removes from source text (`source_text`) all symbols EXCEPT specified in `symbols_list` (`123qwe` + `123` -> `123`);
- 2 - removes from source text (`source_text`) the second and subsequent repetitions of symbol from `symbols_list` (`aabbbcccc` + `ac` -> `abbbc`);';
comment on parameter aux_strip_text.strip_rule is 'Symbol or set of symbols which will be used to replace removed symbols. Empty by default.';