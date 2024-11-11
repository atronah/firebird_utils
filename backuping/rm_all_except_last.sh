#! /bin/sh

# author: atronah (look for me by this nickname on GitHub and GitLab)
# source: https://github.com/atronah/firebird_utils

pushd "$1"

# check and removes old files which match specified name and extension pattern starting from N-file (i.e. keeps last (N-1) files)
# example of using:
# > rm_all_except_last.sh /path/to/checking/files name_part ext_part 4
# it removes all `name_part*ext_part` files in folder `/path/to/checking/files` starting from 4th (i.e. keeps last/newest 3 files)

for f in $(ls -1t $2*$3 | tail -n +$4)
do
        echo removing file "$f" in $(pwd)
        rm "$f"
done

popd
