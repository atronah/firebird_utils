set term ^ ;

create or alter function auxf_damlev_distance(
	src varchar(4096)
	, trg varchar(4096)
)
returns bigint
)
as
begin
	-- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils/tree/master

	return (select distance from aux_damlev_distance(:src, :trg));

	suspend;
end^

set term ; ^

comment on function auxf_damlev_distance is 'Returns Damerau-Levenshtein distance for two strings,
i.e. the minimum number of operations (consisting of insertions, deletions
or substitutions of a single character, or transposition of two adjacent characters)
required to change one word into the other.

Uses procedure `aux_damlev_distance` for that.

------
author: atronah (look for me by this nickname on GitHub and GitLab)
source: https://github.com/atronah/firebird_utils/tree/master
';


comment on parameter auxf_damlev_distance.src is 'Source string';
comment on parameter auxf_damlev_distance.trg is 'Target string';