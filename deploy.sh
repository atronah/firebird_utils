#!/usr/bin/env bash

scriptpath="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

scripts_dir_unix="${scriptpath}"
scripts_dir="${scripts_dir_unix}"
build_dir="${scripts_dir}/builds"
out_dir="${scriptpath}/deploy_result"
deploy_conf="deploy.ini"


if [ -d "$build_dir" ]; then
    rm -fr "$build_dir"
fi

if [ -d "$out_dir" ]; then
    rm -fr "$out_dir"
fi
mkdir "$out_dir"

uname_info="$(uname -s)"
platform_type=unix
case "${uname_info}" in
    Linux*)     platform_type=unix;;
    Darwin*)    platform_type=unix;;
    CYGWIN*)    platform_type=windows;;
    MINGW*)     platform_type=windows;;
    *)          platform_type=unix
esac

if [ $platform_type == "windows" ];  then
    scripts_dir=$(cygpath -w "${scripts_dir}")
fi


# get all rules from `[general]` section of `deploy.ini`
# `-n` - no print each line
# `/\[general\]/,/\[.*\]/p` - prints all lines between `[general]` and `[.*]` blocks
# `s/[ ]*\([^=;\[]*\)=.*/\1/p` - prints all lines, which contains `param=value` after replace all line by `param`
for rule in $(sed -n '/\[general\]/,/\[.*\]/p' "${scripts_dir_unix}/${deploy_conf}" | sed -n -e 's/[ ]*\([^=;\[]*\)=.*/\1/p'); do
    echo $rule
    python3 "${scriptpath}/sql_deploy/compile.py" -d "${scripts_dir}" -s ${deploy_conf} $@ $rule
    mv "${build_dir}/${rule}.sql" "${out_dir}/${rule}.sql"
done

rm -fr "$build_dir"