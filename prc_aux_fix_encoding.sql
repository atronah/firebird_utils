set term ^ ;

create or alter procedure aux_fix_encoding(
    source blob sub_type text
)
returns (
    text blob sub_type text
)
as
begin
    text = source;
    text = replace(text, 'Рђ', 'А');
    text = replace(text, 'Р‘', 'Б');
    text = replace(text, 'Р’', 'В');
    text = replace(text, 'Р“', 'Г');
    text = replace(text, 'Р”', 'Д');
    text = replace(text, 'Р•', 'Е');
    text = replace(text, 'РЃ', 'Ё');
    text = replace(text, 'Р–', 'Ж');
    text = replace(text, 'Р—', 'З');
    text = replace(text, 'Р', 'И');
    text = replace(text, 'Р™', 'Й');
    text = replace(text, 'Рљ', 'К');
    text = replace(text, 'Р›', 'Л');
    text = replace(text, 'Рњ', 'М');
    text = replace(text, 'Рќ', 'Н');
    text = replace(text, 'Рћ', 'О');
    text = replace(text, 'Рџ', 'П');
    text = replace(text, 'Р ', 'Р');
    text = replace(text, 'РЎ', 'С');
    text = replace(text, 'Рў', 'Т');
    text = replace(text, 'РЈ', 'У');
    text = replace(text, 'Р¤', 'Ф');
    text = replace(text, 'РҐ', 'Х');
    text = replace(text, 'Р¦', 'Ц');
    text = replace(text, 'Р§', 'Ч');
    text = replace(text, 'РЁ', 'Ш');
    text = replace(text, 'Р©', 'Щ');
    text = replace(text, 'РЄ', 'Ъ');
    text = replace(text, 'Р«', 'Ы');
    text = replace(text, 'Р¬', 'Ь');
    text = replace(text, 'Р­', 'Э');
    text = replace(text, 'Р®', 'Ю');
    text = replace(text, 'РЇ', 'Я');
    text = replace(text, 'Р°', 'а');
    text = replace(text, 'Р±', 'б');
    text = replace(text, 'РІ', 'в');
    text = replace(text, 'Рі', 'г');
    text = replace(text, 'Рґ', 'д');
    text = replace(text, 'Рµ', 'е');
    text = replace(text, 'С‘', 'ё');
    text = replace(text, 'Р¶', 'ж');
    text = replace(text, 'Р·', 'з');
    text = replace(text, 'Рё', 'и');
    text = replace(text, 'Р№', 'й');
    text = replace(text, 'Рє', 'к');
    text = replace(text, 'Р»', 'л');
    text = replace(text, 'Рј', 'м');
    text = replace(text, 'РЅ', 'н');
    text = replace(text, 'Рѕ', 'о');
    text = replace(text, 'Рї', 'п');
    text = replace(text, 'СЂ', 'р');
    text = replace(text, 'СЃ', 'с');
    text = replace(text, 'С‚', 'т');
    text = replace(text, 'Сѓ', 'у');
    text = replace(text, 'С„', 'ф');
    text = replace(text, 'С…', 'х');
    text = replace(text, 'С†', 'ц');
    text = replace(text, 'С‡', 'ч');
    text = replace(text, 'С€', 'ш');
    text = replace(text, 'С‰', 'щ');
    text = replace(text, 'СЉ', 'ъ');
    text = replace(text, 'С‹', 'ы');
    text = replace(text, 'СЊ', 'ь');
    text = replace(text, 'СЌ', 'э');
    text = replace(text, 'СЋ', 'ю');
    text = replace(text, 'СЏ', 'я');
    
    suspend;
end^

set term ; ^