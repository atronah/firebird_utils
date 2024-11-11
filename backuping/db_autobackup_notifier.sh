#! /bin/sh

# author: atronah (look for me by this nickname on GitHub and GitLab)
# source: https://github.com/atronah/firebird_utils

bot_token="abcdf"
chat_id="-1234567890"
message_prefix="ERROR[ONKO]:"
api_send_message="https://api.telegram.org/bot$bot_token/sendMessage"


curl -X POST -d chat_id=$char_id -d text="$message_prefix Database restore error: $1" $api_send_message
