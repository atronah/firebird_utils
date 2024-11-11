create or alter procedure aux_obfuscare_text(
    text blob sub_type text
    , direction smallint = 0)
returns (
    result blob sub_type text
)
as
declare variable code integer;
declare variable pos integer;
begin
	-- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

	result = '';

	if (direction = 0) then
		begin
			pos = 1;
			while (pos < char_length(text)+1) do
			begin
			result = result || ascii_val(substring(text from pos for 1)) || ',';
			pos = pos + 1;
			end
		end
	else
		begin
			for select part
				from aux_split_text(:text, ',')
				into :code
				do result = result || ascii_char(code);
		end
	suspend;
end