#!/usr/bin/env bash

# console colours
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
NORMAL=$(tput sgr0)

function get_idam_url() {
    if [ "$ENV" == "prod" ]
    then
      url="https://idam-api.platform.hmcts.net"
    else if [ "$ENV" == "local" ]
    then
      url="http://localhost:5000"
    else
      url="https://idam-api.${ENV}.platform.hmcts.net"
    fi
    fi
    echo "$url"
}

function get_idam_token() {
  curl_result=$(
    curl -w $"\n%{http_code}" --silent --show-error -X POST "${IDAM_URL}/o/token" \
      -H "accept: application/json" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=${CLIENT_ID}&client_secret=${IDAM_CLIENT_SECRET}&grant_type=password&username=${ADMIN_USER}&password=${ADMIN_USER_PWD}&redirect_uri=${REDIRECT_URI}&scope=openid roles create-user"
  )

  exit_code=$?
  if ! [ $exit_code -eq 0 ]; then
    # error so echo response and abort
    echo "${RED}ERROR: Token request has failed with exit code: $exit_code${NORMAL}"
    exit $exit_code
  fi

  # seperate body and status into an array
  IFS=$'\n' arr=($curl_result)

  array_length=${#arr[@]}
  http_body=${arr[0]}
  http_status=${arr[${array_length}-1]}

  if [ $(( http_status )) -lt 300 ]; then
    # success so return access token
    idam_token=$(echo "$http_body" | jq -r '.access_token')
    echo "$idam_token"
  else
    # else show error
    if [ $array_length -eq 2 ]; then
      echo "${RED}ERROR: Token request has failed with status: ${http_status}, response:${NORMAL} ${http_body}"
    else
      echo "${RED}ERROR: Token request has failed with status: ${http_status}${NORMAL}"
    fi
    # then quit with non-zero exiit code
    exit $(( http_status ))
  fi
}

function submit_user_registation() {
  local USER=$1

  curl_result=$(
    curl -w $"\n%{http_code}" --silent -X POST "${IDAM_URL}/user/registration" -H "accept: application/json" -H "Content-Type: application/json" \
      -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}" \
      -d "${USER}"
  )

  exit_code=$?
  if ! [ $exit_code -eq 0 ]; then
    # format response in same way as our CURL call: 'BODY\nHTTP_STATUS'
    IFS=$'\n'
    response="ERROR: User registration request has failed with exit code: ${exit_code}${IFS}${exit_code}"
  else
    response=$curl_result
  fi
  echo "$response"
}

function read_password_with_asterisk() {
    unset password
    prompt=$1
    while IFS= read -p "$prompt" -r -s -n 1 char
    do
        if [[ $char == $'\0' ]];     then
            break
        fi
        if [[ $char == $'\177' ]];  then
            prompt=$'\b \b'
            password="${password%?}"
        else
            prompt='*'
            password+="$char"
        fi
    done
    echo "$password"
}

function verify_file_exists() {
  local file=$1

  if ! [ -f $file ]; then
    echo "${RED}ERROR: File not found:${NORMAL} $file"
    exit 99
  fi

  if ! [ -s $file ]; then
      echo "${RED}ERROR: File is empty:${NORMAL} $file"
      exit 99
  fi

}

function verify_csv_tools_are_available() {

  # csvjson for converting CSV -> JSON
  if ! hash csvjson 2>/dev/null; then
    echo "${RED}ERROR: CSVJSON tool not found${NORMAL}: try installing ${YELLOW}csvkit${NORMAL}"
    exit 99
  fi

}

function verify_json_format_includes_field() {
  local json=$1
  local field=$2

  ## verify JSON array is not empty
  if [ $(echo $json | jq -e '. | length') == 0 ]; then
    echo "${RED}ERROR: input file conversion produced empty result.${NORMAL} Please check input file format."
    exit 99
  fi

  ## verify JSON format by checking JUST THE FIRST ITEM has the required field
  if [ $(echo $json | jq "first(.[] | has(\"${field}\"))") == false ]; then
    echo "${RED}ERROR: Field not found in input: ${NORMAL} ${field}"
    exit 99
  fi
}

function convert_input_file_to_json() {
  local file=$1

  verify_csv_tools_are_available

  verify_file_exists ${file}

  # read from CSV by using CSVJSON
  local raw_csv_as_json=$(csvjson $file)

  # verify JSON format  (ie. check mandatory fields are present)
  verify_json_format_includes_field "${raw_csv_as_json}" "email"
  verify_json_format_includes_field "${raw_csv_as_json}" "roles"

  # then reformat JSON using JQ
  local input_as_json=$(echo $raw_csv_as_json \
    | jq -r -c 'map({
        "email": .email,
        "firstName": .firstName,
        "lastName": .lastName,
        "roles": (try(.roles | split("|")) // null)
      })' )

  echo "$input_as_json"
}

function process_input_file() {
  local file=$1

  # convert input file to json
  json="$(convert_input_file_to_json ${CSV_FILE_PATH})"
  check_exit_code_for_error $? "$json"

  # strip JSON into individual compact items then process in a while loop
  echo $json | jq -r -c '.[]' \
      |  \
  ( success_counter=0;fail_counter=0;total_counter=0;
    while IFS= read -r user; do
      total_counter=$((total_counter+1))
      email=$(echo $user | jq --raw-output '.email')

      # make call to IDAM
      response=$(submit_user_registation "$user")
      
      # seperate body and status into an array
      IFS=$'\n' response_array=($response)

      array_length=${#response_array[@]}
      if [ $array_length -eq 1 ]; then
        response_body='' # clear body
        response_status=${response_array[0]}
      else
        response_body=${response_array[0]}
        response_status=${response_array[${array_length}-1]}
      fi

      if [ $(( response_status )) -gt 199 ] && [ $(( response_status )) -lt 300 ]; then
        # SUCCESS:
        success_counter=$((success_counter+1))
        echo "${total_counter}, ${email}, ${user}, ${GREEN}${response_status}${NORMAL}, ${response_body}"
      else
        # FAIL:
        fail_counter=$((fail_counter+1))
        echo "${total_counter}, ${email}, ${user}, ${RED}${response_status}${NORMAL}, ${response_body}"
      fi
    done

    if [ $(( success_counter )) -eq $(( total_counter )) ]; then
      echo "Process is complete: ${GREEN}success: ${success_counter}${NORMAL}, fail: ${fail_counter}, total: ${total_counter}"
    else
      echo "Process is complete: success: ${success_counter}, ${RED}fail: ${fail_counter}${NORMAL}, total: ${total_counter}"
    fi
  )
}

function check_exit_code_for_error() {
  local PREVIOUS_EXIT_CODE=$1;
  local PREVIOUS_RESPONSE=$2;

  if ! [ $PREVIOUS_EXIT_CODE -eq 0 ]; then
    # error so echo response and abort
    echo $PREVIOUS_RESPONSE
    exit $PREVIOUS_EXIT_CODE
  fi
}

# read input arguments
read -p "Please enter csv file path: " CSV_FILE_PATH
read -p "Please enter ccd idam-admin username: " ADMIN_USER
ADMIN_USER_PWD=$(read_password_with_asterisk "Please enter ccd idam-admin password: ")
IDAM_CLIENT_SECRET=$(read_password_with_asterisk $'\nPlease enter idam oauth2 secret for ccd-bulk-user-register client: ')
read -p $'\nPlease enter environment default [prod]: ' ENV

ENV=${ENV:-prod}

if [ -z "${CSV_FILE_PATH}" ] || [ -z "${ADMIN_USER}" ] || [ -z "${ADMIN_USER_PWD}" ] || [ -z "${IDAM_CLIENT_SECRET}" ]
then
  echo "${RED}Please provide all required inputs to the script.${NORMAL} Try running again ./bulk-user-creation.sh"
  exit 1
fi

REDIRECT_URI="https://create-bulk-user-test/oauth2redirect"
CLIENT_ID="ccd-bulk-user-register"
IDAM_URL=$(get_idam_url)
IDAM_ACCESS_TOKEN=$(get_idam_token)
check_exit_code_for_error $? "$IDAM_ACCESS_TOKEN"

if [ -z "$IDAM_ACCESS_TOKEN" ]
then
    echo "${RED}ERROR: Problem getting idam token for admin user:${NORMAL} $ADMIN_USER"
    exit 1
fi

# read csv and call curl in a loop for each record
TIMEFORMAT="The input file was processed in: %3lR"
time process_input_file "${CSV_FILE_PATH}"
