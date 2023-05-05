set term ^ ;

-- escapes some characters
-- list of characters for escaping got from
-- https://www.ibm.com/docs/en/was-liberty/base?topic=SSEQTP_liberty/com.ibm.websphere.wlp.doc/ae/rwlp_xml_escape.htm
create or alter procedure aux_xml_escape(
    source_text blob sub_type text
)
returns(
    text blob sub_type text
)
as
begin
    text = source_text;
    text = replace(text, '"', '&quot;');
    text = replace(text, '''', '&apos;');
    text = replace(text, '<', '&lt;');
    text = replace(text, '>', '&gt;');
    text = replace(text, '&', '&amp;');

    suspend;
end^

set term ; ^