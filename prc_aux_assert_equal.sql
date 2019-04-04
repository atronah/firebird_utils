create or alter exception AUX_ASSERT_EXCEPTION 'ASSERT';

set term ^ ;

create or alter procedure aux_assert_equal(
    left_value varchar(1024) -- Left/first value to comparison
    , right_value varchar(1024) -- Right/second value to comparison
    , message_prefix varchar(1024) = '' -- Prefix for error message
)
as
declare error_message varchar(4096);
begin
    if (left_value is distinct from right_value)
        then exception AUX_ASSERT_EXCEPTION  coalesce(message_prefix, '')
                                                || 'Value `' || coalesce(left_value, 'null')
                                                || '` is not equal to value `'
                                                || coalesce(right_value, 'null') || '`';
end^

set term ; ^

comment on procedure aux_assert_equal is 'Procedure for equality test of two values and throwing exception if they don''t equal'; 
comment on parameter aux_assert_equal.left_value is 'Left/first value to comparison';
comment on parameter aux_assert_equal.right_value is 'Right/second value to comparison';
comment on parameter aux_assert_equal.message_prefix is 'Prefix for error message';

