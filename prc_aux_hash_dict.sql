set term ^ ;
create or alter procedure aux_hash_dict(
    existed_dict varchar(4096)
    , key varchar(255)
    , new_value varchar(255) = null
    , ITEMS_DELIMITER varchar(16) = null
    , KEY_VALUE_DELIMITER varchar(16) = null
)
returns(
    key_hash bigint
    , found_value varchar(255)
    , found_key_start bigint
    , found_value_start bigint
    , found_value_end bigint
    , updated_dict varchar(4096)
)
as
begin
    existed_dict = coalesce(existed_dict, '');
    ITEMS_DELIMITER = trim(coalesce(ITEMS_DELIMITER, ','));
    KEY_VALUE_DELIMITER = trim(coalesce(KEY_VALUE_DELIMITER, ':'));

    key_hash = hash(key);
    updated_dict = existed_dict;

    found_key_start = position(trim(ITEMS_DELIMITER || key_hash || KEY_VALUE_DELIMITER)
                                in ITEMS_DELIMITER || existed_dict);

    if (found_key_start > 0) then
    begin
        found_key_start = found_key_start;
        found_value_start = found_key_start + char_length(key_hash || KEY_VALUE_DELIMITER);
        found_value_end = position(ITEMS_DELIMITER, existed_dict, found_value_start) - 1;
        if (found_value_end <= 0)
            then found_value_end = char_length(existed_dict);

        found_value = substring(existed_dict from found_value_start for found_value_end - found_value_start + 1);
        if (new_value is not null) then
        begin
            updated_dict = substring(updated_dict from 1 for found_value_start - 1)
                                || new_value
                                || substring(updated_dict from found_value_end + 1);
        end
    end
    else if (new_value is not null) then
    begin
        updated_dict = updated_dict
                        || trim(iif(updated_dict > '', ITEMS_DELIMITER, ''))
                        || key_hash || KEY_VALUE_DELIMITER || new_value;
    end

    suspend;
end^

set term ; ^
