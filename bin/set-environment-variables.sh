#!/bin/bash

## set the environment variables for CCD_Data_Store and
## CCD_definition_Store

function set_env_variables() {
    set_env_variables_from_file "${CCD_ENV_FILE:-.env}"
}

function set_env_variables_from_file() {
    file=$1
    if [ -f ${file} ]
    then
        osName="$(uname -s)"
        echo "Setting env variables from [$file] on [$osName]."
        while IFS="=" read -r key value
        do
            if [[ -n "${key}" && "${key:0:1}" != "#" ]]; then
              if [[ "Darwin" == "$osName" || "Linux" == "$osName" ]];then
                export "$key=$value"
              elif [[ "MINGW" == "${osName:0:5}" || "MSYS" == "${osName:0:4}" ]]; then
                setx "$key" "$(echo "$value" | sed -e 's/\r//g')" >/dev/null
              fi
            fi
        done < "$file"
    else
        echo "Environment variable file : $file NOT found. Variables NOT set."
    fi
}

originDir=$PWD
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"
set_env_variables
cd "$originDir"
