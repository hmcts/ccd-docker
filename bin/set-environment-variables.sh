#!/bin/bash

## set the environment variables for CCD_Data_Store and
## CCD_definition_Store

function set_env_variables() {
    set_env_variables_from_file "./env_variables_all.txt"
}

function set_env_variables_from_file() {
    file=$1
    if [ -f ${file} ]
    then
        osName="$(uname -s)"
        echo "Setting env variables from [$file] on [$osName]."
        while IFS="=" read -r key value
        do
            if [[ "Darwin" == "$osName" ]];then
                command="export $key=$value"
                $command
            else 
                setx "$key" $(echo $value | sed -e 's/\r//g')
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

