#!/bin/bash
## set the environment variables for CCD_Data_Store and
## CCD_definition_Store

function set_env_variables() {
    if [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        set_environment_variables_unix
    elif [ "$(expr substr $(uname -s) 1 5)" == "MINGW" ]; then
        set_environment_variables_windows
    fi
}

function set_environment_variables_unix () {
  echo "Setting environment variables on Unix."
  set -a
     source ../env_data_store.txt
     source ../env_definition_store.txt
  set +a
}

function set_environment_variables_windows () {
  echo "Setting environment variables on Windows."
  parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
  cd "$parent_path"
  set_env_variables_from_file "../env_data_store.txt"
  set_env_variables_from_file "../env_definition_store.txt"
}

function set_env_variables_from_file() {
    file=$1
    if [ -f ${file} ]
    then
      echo "$file found."
    while IFS="=" read -r key value
      do
      setx "$key" $(echo $value | sed -e 's/\r//g')
    done < "$file"
    else
      echo "Environment variable file : $file NOT found. Variables NOT set."
    fi

}
set_env_variables
