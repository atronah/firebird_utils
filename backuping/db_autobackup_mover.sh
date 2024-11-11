#! /bin/sh

# author: atronah (look for me by this nickname on GitHub and GitLab)
# source: https://github.com/atronah/firebird_utils

smb_auth_file="/var/db/backups/scripts/samba_fileserver_auth.info"
smb_host="//file-server/scripts"
smb_folder="backups"

ssh_host="other_server"
ssh_host_dir="/home/user"


smbclient $smb_host -A $smb_auth_file -c "put $1 $smb_folder\\$(basename $1)"

rsync -e ssh "$1" $ssh_host:"$ssh_host_dir/$(basename $1)"

