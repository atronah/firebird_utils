set term ^ ;

create or alter procedure aux_xml_escape(
    source_text blob sub_type text
)
returns(
    text blob sub_type text
)
as
begin
    -- author: atronah (look for me by this nickname on GitHub and GitLab)
    -- source: https://github.com/atronah/firebird_utils

    text = source_text;
    text = replace(text, '"', '&quot;');
    text = replace(text, '''', '&apos;');
    text = replace(text, '<', '&lt;');
    text = replace(text, '>', '&gt;');
    text = replace(text, '&', '&amp;');

    suspend;
end^

set term ; ^

comment on procedure aux_xml_escape is 'Escapes some special characters to use them within XML document
(list of characters for escaping was taken from
https://www.ibm.com/docs/en/was-liberty/base?topic=SSEQTP_liberty/com.ibm.websphere.wlp.doc/ae/rwlp_xml_escape.html)';