#!/usr/bin/env bash

# source ./bulk-user-setup.config > out.log 2> /dev/null
source ./bulk-user-setup.config 2> /dev/null

is_test=false

function get_idam_url() {
    if [ "$ENV" == "prod" ]
    then
      url="https://idam-api.platform.hmcts.net"
    elif [ "$ENV" == "local" ]
    then
      url="${IDAM_API_BASE_URL:-http://localhost:5000}"
    else
      url="https://idam-api.${ENV}.platform.hmcts.net"
    fi
    echo "$url"
}

function split_http_response() {
  local raw_response=$1
  local response_array
  local array_length
  local line

  response_array=()
  while IFS= read -r line; do
    response_array+=("$line")
  done <<< "$raw_response"
  array_length=${#response_array[@]}

  if [ "$array_length" -eq 1 ]; then
    response_body=''
    response_status=${response_array[0]}
  else
    response_body=${response_array[0]}
    response_status=${response_array[${array_length}-1]}
  fi
}

function is_success_http_status() {
  local status=$1

  [ $(( status )) -gt 199 ] && [ $(( status )) -lt 300 ]
}

function idam_curl() {
  curl_result=$(curl -w $"\n%{http_code}" --silent "$@")
  exit_code=$?

  if [ "$exit_code" -eq 0 ]; then
    split_http_response "$curl_result"
  fi

  return "$exit_code"
}

function format_status_response() {
  local request_description=$1

  if [ "$exit_code" -eq 0 ]; then
    if is_success_http_status "$response_status"; then
      response="SUCCESS
      ${response_body}"
    else
      response="HTTP-${response_status}
      ${response_body}"
    fi
  else
    response="CURL-${exit_code}
    ERROR: ${request_description} has failed with curl exit code: ${exit_code}"
  fi

  echo "$response"
}

function format_json_response() {
  local curl_error_description=$1
  local http_error_description=$2

  if [ "$exit_code" -eq 0 ]; then
    if is_success_http_status "$response_status"; then
      response=${response_body}
    else
      response="HTTP-${response_status}
      ${response_body}"
      echo "HTTP-${response_status}
      ERROR: ${http_error_description} failed with http response: HTTP-${response_status}"
    fi
  else
    response="CURL-${exit_code}
    ERROR: ${curl_error_description} failed with curl exit code: ${exit_code}"
  fi

  echo "$response"
}

function get_idam_token() {
    curl_result=$(
        curl -w $"\n%{http_code}" --silent --show-error -X POST "${IDAM_URL}/o/token" \
            -H "accept: application/json" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            --data-urlencode "client_id=${CLIENT_ID}" \
            --data-urlencode "client_secret=${IDAM_CLIENT_SECRET}" \
            --data-urlencode "grant_type=password" \
            --data-urlencode "username=${ADMIN_USER}" \
            --data-urlencode "password=${ADMIN_USER_PWD}" \
            --data-urlencode "scope=openid roles create-user manage-user search-user"
        )

  exit_code=$?
  if ! [ $exit_code -eq 0 ]; then
    # error so echo response and abort
    echo "${RED}ERROR: Token request has failed with curl exit code: $exit_code${NORMAL}"
    exit $exit_code
  fi

  # separate body and status into an array
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
    # then quit with non-zero exit code
    exit $(( http_status ))
  fi
}

function submit_user_registation() {
  local USER=$1

  idam_curl -X POST "${IDAM_URL}/api/v1/users/registration" -H "accept: application/json" -H "Content-Type: application/json" \
    -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}" \
    -d "${USER}"

  format_status_response "User registration request"
}

function patch_user_roles() {
  local USERID=$1
  local ROLEID=$2

  idam_curl -X PATCH "${IDAM_URL}/users/${USERID}/roles/${ROLEID}" -H "accept: application/json" -H "Content-Type: application/json" \
    -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"

  format_status_response "User ${USERID} role update request"
}

function post_user_roles() {
  local USER=$1
  local ROLES=$2

  idam_curl -X POST "${IDAM_URL}/api/v1/users/${USER}/roles" -H "accept: application/json" -H "Content-Type: application/json" \
    -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}" \
    -d "${ROLES}"

  format_status_response "User ${USER} role update request"
}

function delete_user() {
  local USER=$1

  idam_curl -X DELETE "${IDAM_URL}/api/v1/users/${USER}" -H "accept: */*" \
    -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"

  format_status_response "User ${USER} delete request"
}

function delete_user_role() {
  local USER=$1
  local ROLE=$2

  idam_curl -X DELETE "${IDAM_URL}/api/v1/users/${USER}/roles/${ROLE}" -H "accept: application/json" -H "Content-Type: application/json" \
    -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"

  format_status_response "User ${USER} role update request"
}

function put_user_roles() {
  local USER=$1
  local ROLES=$2

  idam_curl -X PUT "${IDAM_URL}/api/v1/users/${USER}/roles" -H "accept: application/json" -H "Content-Type: application/json" \
    -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}" \
    -d "${ROLES}"

  format_status_response "User ${USER} role update request"
}

function get_user_api_v1() {
  local ARG=$1
  local QUERY=""

  if [[ "$ARG" == *"@"* ]]; then
    QUERY="email%3A%22${ARG}%22"
  else
    QUERY="ssoId%3A%22${ARG}%22"
  fi

  log_debug "THE QUERY IS:  ${QUERY}"

  idam_curl -X GET -G "${IDAM_URL}/api/v1/users?query=${QUERY}" -H "accept: */*" -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"

  format_json_response "Request for UserID with argument ${ARG}" "Request for UserID with argument ${ARG}"
}

function get_user_by_id_api_v1() {
  local ARG=$1

  idam_curl -X GET -G "${IDAM_URL}/api/v1/users/${ARG}" -H "accept: */*" -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"

  format_json_response "Request for User with id ${ARG}" "Request for User with id ${ARG}"
}

function get_user() {
  local EMAIL=$1

  idam_curl -X GET "${IDAM_URL}/users?email=${EMAIL}" -H "accept: */*" -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"

  format_json_response "Request for UserID with email address ${EMAIL}" "Request for UserID with email address ${EMAIL}"
}


function get_user_roles() {
  local USERID=$1

  idam_curl -X GET "${IDAM_URL}/api/v1/users/${USERID}" -H "accept: */*" -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"

  format_json_response "Request for roles of user UserID ${USERID}" "Request for roles of user UserID ${USERID}"
}

function get_user_by_id() {
  local USERID=$1

  idam_curl -X GET "${IDAM_URL}/api/v1/users/${USERID}" -H "accept: */*" -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"

  format_json_response "Request for roles of user UserID ${USERID}" "Request for roles of user UserID ${USERID}"
}

function get_roles() {

  idam_curl -X GET "${IDAM_URL}/roles" -H "accept: */*" -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"

  format_json_response "Request for get roles" "Request for get roles"
}

function update_user() {
  local USERID=$1
  local USERBODY=$2

  idam_curl -X PATCH "${IDAM_URL}/api/v1/users/${USERID}" -H "accept: application/json" -H "Content-Type: application/json" \
    -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}" \
    -d "${USERBODY}"

  format_json_response "Request for update_user of user UserID ${USERID}" "Request for update_user of user UserID ${USERID}"
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

  if ! [ -f "$file" ]; then
    echo "${RED}ERROR: File not found:${NORMAL} $file"
    exit 99
  fi

  if ! [ -s "$file" ]; then
      echo "${RED}ERROR: File is empty:${NORMAL} $file"
      exit 99
  fi

}

function verify_csv_tools_are_available() {

  # csvjson for converting CSV -> JSON
  if ! hash csvjson 2>/dev/null; then
    echo "${RED}ERROR: CSVJSON tool not found${NORMAL}: try installing ${BOLD}csvkit${NORMAL}"
    exit 99
  fi

}

function verify_json_format_includes_field() {
   local json=$1
   local field=$2

   ## verify JSON array is not empty
   if [ $(echo $json | jq -e '. | length') == 0 ]; then
     echo "${RED}ERROR: input file conversion produced empty result.${NORMAL} Please check input file format."
     log_error "file: ${filename} , ERROR: input file conversion produced empty result.Please check input file format."
     exit 99
   fi

   ## verify JSON format by checking JUST THE FIRST ITEM has the required field
   if [ $(echo $json | jq "first(.[] | has(\"${field}\"))") == false ]; then
     echo "${RED}file: ${filename} ,ERROR: Field not found in input:${NORMAL} ${field}"
     log_error "file: ${filename} , ERROR: Field not found in input:${field}"
     exit 99
   fi
 }

 function verify_json_format_does_not_include_field() {
    local json=$1
    local field=$2

    ## verify JSON array is not empty
    if [ $(echo $json | jq -e '. | length') == 0 ]; then
      echo "${RED}ERROR: input file conversion produced empty result.${NORMAL} Please check input file format."
      log_error "file: ${filename} , ERROR: input file conversion produced empty result.Please check input file format."
      exit 99
    fi

    ## verify JSON format by checking JUST THE FIRST ITEM has the required field
    if [ $(echo $json | jq "first(.[] | has(\"${field}\"))") == true ]; then
      echo "${RED}file: ${filename} ,ERROR: Field found in input:${NORMAL} ${field}"
      log_error "file: ${filename} , ERROR: Field found in input:${field}"
      exit 99
    fi
  }

function get_file_name_from_csv_path() {
  local original_filename=$1

  local dirname=$(dirname "${original_filename}")
  local basename=$(basename "${original_filename}")
  local filename="${basename%.*}"
  local extension="${basename##*.}"

  echo "${filename}.${extension}"
}

function generate_csv_path_with_insert() {
  local original_filename=$1
  local insert=$2

  local dirname=$(dirname "${original_filename}")
  local basename=$(basename "${original_filename}")
  local filename="${basename%.*}"
  local extension="${basename##*.}"

  # add default CSV extension if none was found
  if [ "$extension" = "" ] || [ "$filename" = "$basename" ]; then
    extension="csv"
  fi

  if [[ ! -e "${dirname}/${CSV_PROCESSED_DIR_NAME}" ]]; then
    mkdir -pv "${dirname}/${CSV_PROCESSED_DIR_NAME}"
  fi
  echo "${dirname}/${CSV_PROCESSED_DIR_NAME}/${filename}${insert}.${extension}"
}

function generate_log_path_with_insert() {
  local original_filename=$1
  local insert=$2

  local dirname=$(dirname "${original_filename}")
  local basename=$(basename "${original_filename}")
  local filename="${basename%.*}"
  local extension="${basename##*.}"

  extension="log"

  if [[ ! -e "${dirname}/${CSV_PROCESSED_DIR_NAME}" ]]; then
    mkdir -pv "${dirname}/${CSV_PROCESSED_DIR_NAME}"
  fi

  if [[ "$LOG_PER_INPUT_FILE" = true ]]; then
    echo "${dirname}/${CSV_PROCESSED_DIR_NAME}/${filename}${insert}.${extension}"
  else
    echo "${dirname}/${CSV_PROCESSED_DIR_NAME}/"BULK-SCRIPT-OUTPUT"${insert}.${extension}"
  fi

}

function convert_input_file_to_json() {
  local file=$1

  verify_csv_tools_are_available

  verify_file_exists "$file"

  # read from CSV by using CSVJSON
  local raw_csv_as_json=$(csvjson --datetime-format "." "$file")

  #To get output from the csvjson library call
  #local raw_csv_as_json=$(csvjson --datetime-format "." "$file" 2>&1)

  ## verify raw csv as json is not empty
  if [ -z "$raw_csv_as_json" ]; then
    #printf "%s\n" "${RED}file: ${filename} conversion to JSON produced empty result${NORMAL}"
    #printf "%s\n" "${RED}attempting to convert to UTF-8${NORMAL}"

    #iconv -f ISO-8859-1 -t UTF-8 -c "$file" > "$file-utf8.csv" && mv "$file-utf8.csv" "$file" #&& sleep 3

    #raw_csv_as_json=$(csvjson --datetime-format "." "$file")

    #if [ -z "$raw_csv_as_json" ]; then
    #    echo "${RED}file: ${filename} ,ERROR: input file conversion produced empty result.${NORMAL} Please check input file format."
    #    log_error "file: ${filename} , ERROR: input file conversion produced empty result.Please check input file format."
    #    exit 99
    #fi
    #printf "%s\n" "${raw_csv_as_json}"

    echo "${RED}file: ${filename} ,ERROR: input file conversion produced empty result.${NORMAL} Please check input file format."
    log_error "file: ${filename} , ERROR: input file conversion produced empty result.Please check input file format."
    exit 99
  fi

  # verify JSON format  (ie. check mandatory fields are present)
  verify_json_format_includes_field "${raw_csv_as_json}" "operation"
  verify_json_format_includes_field "${raw_csv_as_json}" "email"
  verify_json_format_includes_field "${raw_csv_as_json}" "firstName"
  verify_json_format_includes_field "${raw_csv_as_json}" "lastName"
  verify_json_format_includes_field "${raw_csv_as_json}" "roles"

  #if [[ "$ENABLE_USERID_REGISTRATIONS" = true ]]; then
  #  verify_json_format_includes_field "${raw_csv_as_json}" "id"
  #else
  #  verify_json_format_does_not_include_field "${raw_csv_as_json}" "id"
  #fi

  if [[ "$ENABLE_USERID_REGISTRATIONS" = true ]]; then
    verify_json_format_includes_field "${raw_csv_as_json}" "id"
  fi

  #"roles": (try(.roles | split("|") | walk( if type == "string" then (sub("^[[:space:]]+"; "") | sub("[[:space:]]+$"; "")) else . end)) // null),

  # then reformat JSON using JQ
  local input_as_json=$(echo $raw_csv_as_json \
    | jq -r -c 'map({
        "idamUser": {
          "email": (try(.email | sub("^[[:space:]]+"; "") | sub("[[:space:]]+$"; "")) // null),
          "id": .id,
          "ssoId": .ssoId,
          "firstName": .firstName,
          "lastName": .lastName,
          "roles": (try(.roles | split("|") | walk( if type == "string" then (sub("^[[:space:]]+"; "") | sub("[[:space:]]+$"; "")) else . end)) // null),
          "rolesToAdd": (try(.rolesToAdd | split("|")) // null),
          "rolesToRemove": (try(.rolesToRemove | split("|")) // null)
        },
        "extraCsvData": {
          "operation": .operation,
          "roles": .roles,
          "status": .status,
          "responseMessage": .responseMessage,
          "idamUserJson": .idamUserJson,
          "timestamp": .timestamp,
          "result": .result
        }
      })' ) # NB: extraCsvData element included in JSON to help preserve csv data when skipping an already complete record (i.e. inviteStatus="success")

  echo "$input_as_json"

}

function set_processing_file_paths() {
  local filepath_input_original=$1

  datestamp=$(date -u +"%FT%H%M%SZ")
  filepath_input_newpath=$(generate_csv_path_with_insert "$filepath_input_original" "_Input_${datestamp}")
  filepath_output_newpath=$(generate_csv_path_with_insert "$filepath_input_original" "_Output_${datestamp}")
  filename=$(get_file_name_from_csv_path "$filepath_input_original")

  # fix for bug moving the original file to output folder with new name
  # i.e. rename working 'output' naming to input
  filepath_input_newpath2=${filepath_output_newpath/Output/Input}
}

function set_log_file_for_input() {
  local filepath_input_original=$1

  if [[ "$LOG_PER_INPUT_FILE" = true ]]; then
    LOGFILE="$(generate_log_path_with_insert "$filepath_input_original" "${datestamp}")"
  else
    local datestamp_day=$(date -u +"%F")
    LOGFILE="$(generate_log_path_with_insert "$filepath_input_original" "${datestamp_day}")"
  fi
}

function print_test_file_paths() {
  echo 'Test outputs of resulting files!'
  echo "$filepath_input_original"
  echo "$filepath_input_newpath"
  echo "$filepath_output_newpath"
  echo "$filepath_input_newpath2"
  echo "$IDAM_ACCESS_TOKEN"
}

function move_input_file_to_backup() {
  if [[ "$is_test" = true ]]; then
    return
  fi

  mv "$filepath_input_original" "$filepath_input_newpath2" 2> /dev/null

  if [ $? -eq 0 ]; then
    echo "Moved input file to backup location: ${BOLD}${filepath_input_newpath2}${NORMAL}"
  else
    echo "${RED}ERROR: Aborted as unable to move input file to backup location:${NORMAL} ${filepath_input_newpath2}"
    exit 1
  fi
}

function write_output_header() {
  echo "operation,email,firstName,lastName,roles,isActive,lastModified,ssoID,status,responseMessage" >> "$filepath_output_newpath"
}

function reset_processing_counters() {
  success_counter=0
  skipped_counter=0
  fail_counter=0
  total_counter=0
  test_pass_counter=0
  test_fail_counter=0
  isResultColumnPresent=0
}

function is_error_response() {
  local raw_response=$1

  [[ ${raw_response} == *"HTTP-"* ]] || [[ ${raw_response} == *"ERROR"* ]]
}

function load_user_record_context() {
  user=$1
  isActive=" "
  lastModified=" "
  outputSSOId=" "
  userId=""
  userActiveState=""
  firstNameFromApi=""
  lastNameFromApi=""
  usersRolesFromApi="[]"
  responseMessage=""
  bRolesDiscarded=false
  discardedRolesMessage=""

  email=$(echo "$user" | jq --raw-output '.idamUser.email')
  email=$(trim "$email")
  email=$(convertToLowerCase "$email")

  firstName=$(echo "$user" | jq --raw-output '.idamUser.firstName')
  firstName=$(trim "$firstName")

  lastName=$(echo "$user" | jq --raw-output '.idamUser.lastName')
  lastName=$(trim "$lastName")

  operation=$(echo "$user" | jq --raw-output '.extraCsvData.operation')
  operation=$(trim "$operation")
  operation=$(convertToLowerCase "$operation")

  rolesFromCSV=$(echo "$user" | jq --raw-output '.idamUser.roles')

  strRolesFromCSV=$(echo "$user" | jq --raw-output '.extraCsvData.roles')
  strRolesFromCSV=$(trim "$strRolesFromCSV")

  idamUserJson=$(echo "$user" | jq -c --raw-output '.idamUser')

  # inviteStatus from input CSV can take value SUCCESS; if it is present,
  # avoid re-submitting a registration request that is already pending.
  inviteStatus=$(echo "$user" | jq --raw-output '.extraCsvData.status')
  result=$(echo "$user" | jq --raw-output '.extraCsvData.result')

  csvUserId=$(echo "$user" | jq --raw-output '.idamUser.id')
  csvSSOId=$(echo "$user" | jq --raw-output '.idamUser.ssoId')
  csvSSOId=$(trim "$csvSSOId")
}

function log_user_record_start() {
  log_debug "==============================================="

  if [ "$email" != "null" ]; then
    log_debug "processing user with email: ${email}"
  elif [ "$csvUserId" != "null" ]; then
    log_debug "processing user with id: ${csvUserId}"
  fi
}

function load_api_user_context() {
  userId=$(echo "${rawReturnedValue}" | jq --raw-output '.id')
  userActiveState=$(echo "${rawReturnedValue}" | jq --raw-output '.active')
  isActive="${userActiveState}"

  email=$(echo "${rawReturnedValue}" | jq --raw-output '.email')
  email=$(trim "$email")
  email=$(convertToLowerCase "${email}")

  firstNameFromApi=$(echo "${rawReturnedValue}" | jq --raw-output '.forename')
  lastNameFromApi=$(echo "${rawReturnedValue}" | jq --raw-output '.surname')
  usersRolesFromApi=$(echo "$rawReturnedValue" | jq --raw-output '.roles')
  lastModified=$(echo "$rawReturnedValue" | jq --raw-output '.lastModified')
}

function lookup_user_for_record() {
  rawReturnedValue="HTTP-404"

  if [ "$csvSSOId" != "null" ]; then
    rawReturnedValueArray=$(get_user_api_v1 "${csvSSOId}")
  elif [ "$csvUserId" != "null" ]; then
    rawReturnedValueArray=$(get_user_by_id_api_v1 "${csvUserId}")
  else
    rawReturnedValueArray=$(get_user_api_v1 "${email}")
  fi

  if ! is_error_response "$rawReturnedValueArray"; then
    if [ "$(echo "$rawReturnedValueArray" | jq -e '. | length')" != 0 ]; then
      if [ "$csvUserId" != "null" ]; then
        rawReturnedValue="$rawReturnedValueArray"
      elif [ "$csvSSOId" != "null" ]; then
        for userJson in $(echo "$rawReturnedValueArray" | jq -c -r '.[]'); do
          local apiSSOId=$(echo "$userJson" | jq --raw-output '.ssoId')
          if [ "${apiSSOId}" = "${csvSSOId}" ]; then
            rawReturnedValue=${userJson}
            break
          fi
        done
      else
        rawReturnedValue=$(echo "$rawReturnedValueArray" | jq '.[]' | jq --slurp '.[0]')
      fi
    fi
  fi

  if [ "$csvSSOId" != "null" ]; then
    outputSSOId="${csvSSOId}"
  fi

  if ! is_error_response "$rawReturnedValue"; then
    load_api_user_context
  fi
}

function normalise_roles_from_csv() {
  log_debug "original roles from CSV: ${rolesFromCSV}"

  if [ "$(echo "$rolesFromCSV" | jq -e '. | length')" != 0 ]; then
    rolesFromCSV=$(convertJsonStringArrayToLowerCase "${rolesFromCSV}")
  fi
}

function warn_about_unused_input_fields() {
  if [ "$operation" == "find" ] || [ "$operation" == "delete" ]; then
    local icount=0
    local strReason="the following fields were provided but are not required: "
    if [[ "$strRolesFromCSV" != "null" ]] && [ "$operation" == "find" ]; then
      icount=$((icount+1))
      strReason="${strReason} roles,"
    fi
    if [[ "$firstName" != "null" ]]; then
      icount=$((icount+1))
      strReason="${strReason} firstName,"
    fi
    if [[ "$lastName" != "null" ]]; then
      icount=$((icount+1))
      strReason="${strReason} lastName,"
    fi

    if [ "$icount" -gt 0 ]; then
      log_warn "file: ${filename} , action: ${operation}, email: ${email} , status: ${strReason}"
    fi
  fi

  if [ "$operation" == "updatename" ]; then
    local strReason="the following fields were provided but are not required: roles"
    if [[ "$strRolesFromCSV" != "null" ]]; then
      log_warn "file: ${filename} , action: ${operation}, email: ${email} , status: ${strReason}"
    fi
  fi
}

function build_standard_output_csv() {
  local current_user=$1
  local input_csv

  input_csv=$(echo "$current_user" | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
  output_csv="$input_csv,\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""
}

function build_find_output_csv() {
  local current_user=$1
  local input_csv

  input_csv=$(echo "$current_user" | jq -r '[.extraCsvData.operation, .idamUser.email] | @csv')
  output_csv="$input_csv,\"$firstNameFromApi\",\"$lastNameFromApi\",\"$strApi_v1_user_roles\",\"$isActive\",\"$lastModified\",\"\"$userId\"\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""
}

function build_userid_registration_output_csv() {
  local current_user=$1
  local input_csv

  input_csv=$(echo "$current_user" | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
  output_csv="$input_csv,\"$userId\",\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""
}

function parse_submit_response() {
  local submit_response=$1
  local response_array
  local line

  response_array=()
  while IFS= read -r line; do
    response_array+=("$line")
  done <<< "$submit_response"
  inviteStatus=${response_array[0]}
  responseMessage=${response_array[1]}
}

function update_expected_result_counters() {
  if [[ "$result" != "null" ]]; then
    isResultColumnPresent=1
    if [ "${result}" == "${inviteStatus}" ]; then
      test_pass_counter=$((test_pass_counter+1))
    else
      test_fail_counter=$((test_fail_counter+1))
      log_debug "test failed at record number: $((total_counter+1))"
    fi
  fi
}

function is_valid_operation() {
  [ "$(contains "${OPS[@]}" "${operation}")" == "y" ]
}

function roles_csv_is_empty() {
  [ "$(echo "$rolesFromCSV" | jq -e '. | length')" == 0 ]
}

function operation_requires_roles() {
  [ "$operation" == "add" ] || [ "$operation" == "delete" ]
}

function role_string_is_invalid() {
  [ "$(validateRoleString "${strRolesFromCSV}")" -eq 0 ]
}

function manual_delete_role_requested() {
  [ "$(checkAllowedRole "${rolesFromCSV}" "${MANUAL_ROLES}")" -eq 1 ]
}

function print_processing_summary() {
  echo "${NORMAL}Process is complete: ${GREEN}success: ${success_counter}${NORMAL}, ${YELLOW}skipped: ${skipped_counter}${NORMAL}, ${RED}fail: ${fail_counter}${NORMAL}, total: ${total_counter}"
}

function log_expected_result_summary() {
  if [ "$isResultColumnPresent" -eq 1 ]; then
    local testResult=""
    if [ "$test_pass_counter" -gt 0 ] && [ "$test_fail_counter" -eq 0 ]; then
      echo "**** ${GREEN}ALL TESTS PASSED${NORMAL} ****"
      testResult="**** ALL TESTS PASSED ****"
    elif [ "$test_pass_counter" -eq 0 ] && [ "$test_fail_counter" -gt 0 ]; then
      echo "**** ${RED}ALL TESTS FAILED${NORMAL} ****"
      testResult="**** ALL TESTS FAILED ****"
    else
      echo "**** ${YELLOW}NOT ALL TESTS PASSED${NORMAL} ****"
      testResult="**** NOT ALL TESTS PASSED ****"
    fi
    log_info "${testResult}"
  fi
}

function fail_record() {
  local reason=$1

  fail_counter=$((fail_counter+1))
  responseMessage="ERROR: $reason"
  inviteStatus="FAILED"
  log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
  echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}${reason}${NORMAL}"
}

function skip_record() {
  local reason=$1

  skipped_counter=$((skipped_counter+1))
  inviteStatus="SKIPPED"
  responseMessage="WARN: $reason"
  log_warn "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
  echo "${NORMAL}${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${reason}${NORMAL}"
}

function fail_invalid_operation() {
  fail_record "Operation '${operation}' is invalid"
  build_standard_output_csv "$user"
}

function fail_invalid_email() {
  fail_record "${InvalidEmailDetected}"
  build_standard_output_csv "$user"
}

function fail_no_roles_defined() {
  fail_record "${NoRolesDefined}"
  build_standard_output_csv "$user"
}

function fail_invalid_role_string() {
  fail_record "${RolesDefinedContainInvalidCharacters}"
  build_standard_output_csv "$user"
}

function fail_sso_user_not_found() {
  fail_record "${userNotFound} with provided ssoID"
  build_standard_output_csv "$user"
}

function fail_find_user_not_found() {
  fail_record "${userNotFound}"
  build_standard_output_csv "$user"
}

function handle_already_processed_record() {
  local reason="Request already processed previously"

  skipped_counter=$((skipped_counter+1))
  responseMessage="WARN: $reason"
  echo "${NORMAL}${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${inviteStatus} - ${reason}${NORMAL}"
  log_warn "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
  build_standard_output_csv "$user"
}

function handle_find_user() {
  local strApi_v1_user_roles=""
  local reason="User details successfully retrieved"

  for apiRole in $(echo "${usersRolesFromApi}" | jq -r '.[]'); do
    if [ "${strApi_v1_user_roles}" = "" ]; then
      strApi_v1_user_roles="${apiRole}"
    else
      strApi_v1_user_roles="$strApi_v1_user_roles|${apiRole}"
    fi
  done

  success_counter=$((success_counter+1))
  responseMessage=""
  inviteStatus="SUCCESS"
  log_debug "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
  echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}${reason}${NORMAL}"
  build_find_output_csv "$user"
}

function discard_manual_roles_for_add() {
  bRolesDiscarded=false
  discardedRolesMessage=""

  if [ "$(checkAllowedRole "${rolesFromCSV}" "${MANUAL_ROLES}")" -eq 1 ]; then
    local discardedRoles
    discardedRoles=$(returnNotAllowedRoles "${rolesFromCSV}" "${MANUAL_ROLES}")
    rolesFromCSV=$(stripNotAllowedRoles "${rolesFromCSV}" "${MANUAL_ROLES}")
    discardedRolesMessage="WARN: the following role(s) can only be added by eJust 3rd Line support via Snow: "
    discardedRolesMessage="$discardedRolesMessage ${discardedRoles[*]}"
    log_warn "file: ${filename} , action: ${operation} , email: ${email} , status: ${discardedRolesMessage}"
    bRolesDiscarded=true
  fi
}

function add_default_roles_when_required() {
  if [ "$(checkShouldAddDefaultRoles "${rolesFromCSV}")" -eq 1 ]; then
    log_debug "Adding default roles"
    rolesFromCSV=$(addRolesToCSVRoles "${rolesFromCSV}" "${ADD_ROLES_BY_DEFAULT}")
  else
    log_debug "Skipping addition of default roles"
  fi
}

function set_blank_registration_names() {
  if [[ "$firstName" == "null" ]]; then
    log_debug "firstName is empty setting to ' '"
    idamUserJson=$(echo "$idamUserJson" | jq '.firstName = " "')
  elif [[ "$lastName" == "null" ]]; then
    log_debug "lastName is empty setting to ' '"
    idamUserJson=$(echo "$idamUserJson" | jq '.lastName = " "')
  fi
}

function record_registration_response() {
  local submit_response=$1

  parse_submit_response "$submit_response"

  if [ "$inviteStatus" == "SUCCESS" ]; then
    success_counter=$((success_counter+1))
    lastModified=$(date -u +"%FT%H:%M:%SZ")
    local reason="user successfully registered"
    responseMessage="INFO: $reason"

    if [[ "$bRolesDiscarded" = true ]]; then
      responseMessage="$responseMessage $discardedRolesMessage"
    fi

    log_debug "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
    echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}${reason}${NORMAL}"
  else
    fail_counter=$((fail_counter+1))
    local reason="failed registering user"
    responseMessage="ERROR: $responseMessage"
    inviteStatus="FAILED"
    echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${responseMessage}${NORMAL}"
    log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason} - ${responseMessage}"
  fi
}

function handle_add_with_userid_registration() {
  if [ "$csvUserId" == "null" ]; then
    skip_record "Field: 'userId' required, but not provided"
  elif [ "$firstName" == "null" ] && [ "$lastName" == "null" ]; then
    fail_record "${BothFirstAndLastnameCannotBeEmpty}"
  else
    if [ "$csvUserId" == "use-existing-user-id" ]; then
      log_debug "${email}, existing user with id: ${userId}"
      idamUserJson=$(echo "$idamUserJson" | jq --arg existingUserID "${userId}" '.id = ($existingUserID)')
    fi

    log_debug "idamUserJson: ${idamUserJson}"
    submit_response=$(submit_user_registation "$idamUserJson")
    record_registration_response "$submit_response"
  fi

  build_userid_registration_output_csv "$user"
}

function handle_add_new_user() {
  log_debug "email: ${email} - User does not exist, doing add new user logic"

  if [ "$firstName" == "null" ] && [ "$lastName" == "null" ]; then
    fail_record "${BothFirstAndLastnameCannotBeEmpty}"
  else
    discard_manual_roles_for_add
    add_default_roles_when_required

    log_debug "Final roles to apply: ${rolesFromCSV}"
    set_blank_registration_names

    if [ "${rolesFromCSV}" = "[]" ]; then
      fail_counter=$((fail_counter+1))
      local reason="No resulting roles to apply"
      responseMessage="ERROR: $reason"

      if [[ "$bRolesDiscarded" = true ]]; then
        responseMessage="$responseMessage $discardedRolesMessage"
      fi

      inviteStatus="FAILED"
      echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${responseMessage}${NORMAL}"
      log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason} - ${responseMessage}"
    else
      idamUserJson=$(echo "$idamUserJson" | jq --argjson rolesFromCSV "${rolesFromCSV}" '.roles = $rolesFromCSV')
      log_debug "idamUserJson: ${idamUserJson}"
      submit_response=$(submit_user_registation "$idamUserJson")
      record_registration_response "$submit_response"
    fi
  fi

  build_standard_output_csv "$user"
}

function handle_delete_user_account() {
  log_debug "email: ${email} - User exists, doing delete user logic"

  submit_response=$(delete_user "${userId}")

  if [[ $submit_response =~ .*SUCCESS.* ]]; then
    isActive="FALSE"
    success_counter=$((success_counter+1))
    inviteStatus="SUCCESS"
    lastModified=$(date -u +"%FT%H:%M:%SZ")
    local reason="User successfully deleted"
    responseMessage="INFO: $reason"

    log_info "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
    echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}${reason}${NORMAL}"
  else
    fail_counter=$((fail_counter+1))
    inviteStatus="FAILED"
    local reason="User could not be deleted"
    responseMessage="ERROR: $reason"

    log_error "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
    echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${responseMessage}${NORMAL}"
  fi

  build_standard_output_csv "$user"
}

function handle_suspend_user() {
  log_debug "email: ${email} - User exists, doing suspend user logic"

  if [ "$userActiveState" == "true" ]; then
    log_debug "email: ${email} - User activate state=true, deactivating user"
    body='{"active":false}'
    submit_response=$(update_user "${userId}" "${body}")

    if [[ $submit_response =~ .*email.* ]]; then
      isActive="FALSE"
      success_counter=$((success_counter+1))
      inviteStatus="SUCCESS"
      lastModified=$(date -u +"%FT%H:%M:%SZ")
      local reason="User successfully deactivated"
      responseMessage="INFO: $reason"

      log_info "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
      echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}${reason}${NORMAL}"
    else
      fail_counter=$((fail_counter+1))
      inviteStatus="FAILED"
      local reason="User active state could not be set to false"
      responseMessage="ERROR: $reason"

      log_error "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
      echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${responseMessage}${NORMAL}"
    fi
  else
    skip_record "${UserExistsNotActive}"
  fi

  build_standard_output_csv "$user"
}

function handle_unsuspend_user() {
  log_debug "email: ${email} - User exists, doing unsuspend user logic"

  if [ "$userActiveState" == "false" ]; then
    log_debug "email: ${email} - User activate state=false, activating user"
    body='{"active":true}'
    submit_response=$(update_user "${userId}" "${body}")

    if [[ $submit_response =~ .*email.* ]]; then
      isActive="TRUE"
      success_counter=$((success_counter+1))
      inviteStatus="SUCCESS"
      lastModified=$(date -u +"%FT%H:%M:%SZ")
      local reason="User successfully activated"
      responseMessage="INFO: $reason"

      log_info "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
      echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}${reason}${NORMAL}"
    else
      fail_counter=$((fail_counter+1))
      inviteStatus="FAILED"
      local reason="User active state could not be set to true"
      responseMessage="ERROR: $reason"

      log_error "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
      echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${responseMessage}${NORMAL}"
    fi
  else
    skip_record "${UserExistsActive}"
  fi

  build_standard_output_csv "$user"
}

function build_unique_roles_to_add_json() {
  local rolesToAdd=()
  local csvRole
  local apiRole
  local found
  local roles_json='[]'

  for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
    found=0
    for apiRole in $(echo "${usersRolesFromApi}" | jq -r '.[]'); do
      if [ "$csvRole" == "$apiRole" ]; then
        found=1
        log_debug "email: ${email}, role: $csvRole  - already assigned"
      fi
    done
    if [ "$found" -eq 0 ]; then
      csvRole=$(convertToLowerCase "${csvRole}")
      log_debug "email: ${email}, role: $csvRole  - Unique (TO BE ADDED)"
      rolesToAdd+=("${csvRole}")
    fi
  done

  for csvRole in "${rolesToAdd[@]}"; do
    roles_json=$(jq -n --arg x "$csvRole" --argjson arr "$roles_json" '$arr + [$x]')
  done

  echo "${roles_json}" | jq 'map( {"name" : . } ) | unique'
}

function activate_user_after_role_add_if_required() {
  if [ "$userActiveState" == "false" ] && [ "$SET_INACTIVE_USER_TO_ACTIVE" = "true" ]; then
    log_debug "email: ${email} - User activate state=false, activating user"
    local body='{"active":true}'
    local submit_response

    submit_response=$(update_user "${userId}" "${body}")

    if [[ $submit_response =~ .*email.* ]]; then
      log_info "file: ${filename} , email: ${email} - SUCCESS, user active state set to true"
      isActive="TRUE"
      responseMessage="INFO: user has been activated"
    else
      log_error "file: ${filename} , email: ${email} - FAILED, user active state could not be set"
      responseMessage="ERROR: user active state could not be set to true"
    fi
  fi
}

function handle_add_roles_to_existing_user() {
  log_debug "email: ${email} - User exists, doing role addition logic"
  log_debug "Current assigned roles (based on API): ${usersRolesFromApi}"

  discard_manual_roles_for_add
  add_default_roles_when_required

  local uniqueRolesJson
  uniqueRolesJson=$(build_unique_roles_to_add_json)

  log_debug "Final roles to apply: ${uniqueRolesJson}"

  if [ "${uniqueRolesJson}" != "[]" ]; then
    submit_response=$(post_user_roles "$userId" "$uniqueRolesJson")
    parse_submit_response "$submit_response"

    if [ "$inviteStatus" == "SUCCESS" ]; then
      success_counter=$((success_counter+1))
      lastModified=$(date -u +"%FT%H:%M:%SZ")
      inviteStatus="SUCCESS"
      local reason="role(s) successfully assigned"
      echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}$reason${NORMAL}"
      log_debug "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
      responseMessage=""

      activate_user_after_role_add_if_required

      if [[ "$bRolesDiscarded" = true ]]; then
        responseMessage="$responseMessage $discardedRolesMessage"
      fi
    else
      fail_counter=$((fail_counter+1))
      inviteStatus="FAILED"
      local reason="failed assigning one or more roles"
      responseMessage="ERROR: $responseMessage"
      if [[ $responseMessage = *"account is stale"* ]]; then
        responseMessage="$responseMessage INFO: user needs to reset their password themselves for the account to be reactivated"
      fi
      echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${responseMessage}${NORMAL}"
      log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason} - ${responseMessage}"
    fi
  else
    skipped_counter=$((skipped_counter+1))
    inviteStatus="SKIPPED"
    local reason="required roles are already assigned, no role amendments required"
    responseMessage="WARN: $reason"

    if [[ "$bRolesDiscarded" = true ]]; then
      responseMessage="$responseMessage $discardedRolesMessage"
    fi

    log_warn "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
    echo "${NORMAL}${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${reason}${NORMAL}"
  fi

  build_standard_output_csv "$user"
}

function handle_update_email() {
  if [ "$csvSSOId" != "null" ]; then
    log_debug "ssoID: ${csvSSOId} - User exists, doing update email logic"
  else
    log_debug "email: ${email} - User exists, doing update email logic"
  fi

  local emailFromApi
  emailFromApi=$(echo "${rawReturnedValue}" | jq --raw-output '.email')

  if [ "$userActiveState" == "true" ] || [ "$PROCESS_INACTIVE_USER" = "true" ]; then
    if [ "${email}" != "${emailFromApi}" ]; then
      if [ "$email" == "null" ]; then
        fail_record "Email cannot be empty"
      else
        log_debug "email: ${email} - doing email update"

        local body='{"email": "'${email}'"}'
        submit_response=$(update_user "${userId}" "${body}")
        parse_submit_response "$submit_response"

        if [[ $submit_response =~ .*email.* ]]; then
          success_counter=$((success_counter+1))
          lastModified=$(date -u +"%FT%H:%M:%SZ")
          inviteStatus="SUCCESS"
          local reason="user email successfully updated"
          log_debug "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
          echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}${reason}${NORMAL}"
        else
          fail_counter=$((fail_counter+1))
          inviteStatus="FAILED"
          local reason="failed updating user email"
          log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
          echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${responseMessage}${NORMAL}"
        fi
      fi
    else
      skip_record "no changes in email, nothing to update"
    fi
  else
    skip_record "${UserExistsNotActive}"
  fi

  build_standard_output_csv "$user"
}

function build_name_update_body() {
  if [ "$firstName" == "null" ] && [ "$lastName" != "null" ]; then
    jq -nc --arg lastName "$lastName" '{surname: $lastName}'
  elif [ "$lastName" == "null" ] && [ "$firstName" != "null" ]; then
    jq -nc --arg firstName "$firstName" '{forename: $firstName}'
  else
    jq -nc --arg firstName "$firstName" --arg lastName "$lastName" '{forename: $firstName, surname: $lastName}'
  fi
}

function handle_update_name() {
  log_debug "email: ${email} - User exists, doing update firstname lastname logic"

  if [ "$userActiveState" == "true" ] || [ "$PROCESS_INACTIVE_USER" = "true" ]; then
    if [ "${firstName}" != "${firstNameFromApi}" ] || [ "$lastName" != "${lastNameFromApi}" ]; then
      if [ "$firstName" == "null" ] && [ "$lastName" == "null" ]; then
        fail_record "${BothFirstAndLastnameCannotBeEmpty}"
      else
        log_debug "email: ${email} - doing firstname/lastname update"

        local body
        body=$(build_name_update_body)
        submit_response=$(update_user "${userId}" "${body}")
        parse_submit_response "$submit_response"

        if [[ $submit_response =~ .*email.* ]]; then
          success_counter=$((success_counter+1))
          lastModified=$(date -u +"%FT%H:%M:%SZ")
          inviteStatus="SUCCESS"
          local reason="user firstname/lastname successfully updated"
          log_debug "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
          echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}${reason}${NORMAL}"
        else
          fail_counter=$((fail_counter+1))
          inviteStatus="FAILED"
          local reason="failed updating user firstname/lastname"
          log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
          echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${responseMessage}${NORMAL}"
        fi
      fi
    else
      skip_record "no changes in firstname/lastname detected, nothing to update"
    fi
  else
    skip_record "${UserExistsNotActive}"
  fi

  build_standard_output_csv "$user"
}

function handle_missing_user_for_operation() {
  skip_record "User does not exist, cannot process $operation operation"
  build_standard_output_csv "$user"
}

function fail_manual_role_delete_request() {
  fail_record "One or more roles defined cannot be assigned using this script"
  build_standard_output_csv "$user"
}

function determine_delete_roles_strategy() {
  USE_PUT=0
  default_caseworker_role_provided=false
  default_caseworker_role_already_assigned=false
  rolesToRemoveArray=()
  rolesFromApiArray=()

  log_debug "Current assigned roles (based on API): ${usersRolesFromApi}"

  if [ "$(checkJsonContainsStringRole "${rolesFromCSV}" "${ALL_ROLES}")" -eq 1 ]; then
    log_debug "Operation: ${operation}, contains role:  ${ALL_ROLES}, PUT API call will be used to remove all roles and de-activate the user"
    USE_PUT=1
  elif [ "$(echo "$usersRolesFromApi" | jq -e '. | length')" == 0 ]; then
    log_debug "Operation: ${operation}, User currently has NO roles assigned, PUT API call will be used to de-activate the user"
    USE_PUT=1
  else
    for apiRole in $(echo "${usersRolesFromApi}" | jq -r '.[]'); do
      if [ "$apiRole" == "${ADD_ROLES_BY_DEFAULT}" ]; then
        default_caseworker_role_already_assigned=true
      fi
      rolesFromApiArray+=("${apiRole}")
    done

    rolesFromCSV=$(addPreDefinedRolesToCSVRoles "${rolesFromCSV}")
    log_debug "Computed/expanded CSV roles supplied for deletion: ${rolesFromCSV}"

    for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
      if [ "$csvRole" == "${ADD_ROLES_BY_DEFAULT}" ]; then
        default_caseworker_role_provided=true
      fi
      if [ "$(checkArrayContainsStringRole "${IGNORED_ROLES_FROM_USER_DELETE_REQUEST}" "${csvRole}")" -eq 1 ]; then
        log_debug "Ignoring supplied role: ${csvRole}"
      else
        for apiRole in "${rolesFromApiArray[@]}"; do
          if [ "$csvRole" == "$apiRole" ]; then
            rolesToRemoveArray+=("${csvRole}")
            break
          fi
        done
      fi
    done

    rolesFromApiArray=($(removeFromArray2 "${rolesFromApiArray}" "${rolesToRemoveArray}"))

    local otherServiceRole=false
    for apiRole in "${rolesFromApiArray[@]}"; do
      if [[ "${apiRole}" == "${ADD_ROLES_BY_DEFAULT}-"* ]]; then
        otherServiceRole=true
        break
      fi
    done

    if [[ "$otherServiceRole" = false ]]; then
      for apiRole in "${rolesFromApiArray[@]}"; do
        if [ "$(checkArrayContainsStringRole "${DELETE_ROLES_BY_DEFAULT}" "${apiRole}")" -eq 1 ]; then
          rolesFromApiArray=($(removeFromArray2 "${rolesFromApiArray}" "${apiRole}"))
          rolesToRemoveArray+=("${apiRole}")
        fi
      done
    fi

    local rolesFromApiArray_count=${#rolesFromApiArray[@]}

    log_debug "default_caseworker_role_provided = ${default_caseworker_role_provided}"
    log_debug "default_caseworker_role_already_assigned = ${default_caseworker_role_already_assigned}"
    log_debug "Any more caseworker- roles remaining = ${otherServiceRole}"
    log_debug "rolesFromApiArray_count after deletions would be: ${rolesFromApiArray_count}"
    log_debug "API based roles remaining after deletions would be: ${rolesFromApiArray[*]}"
    log_debug "Assigned roles to remove: ${rolesToRemoveArray[*]}"

    if [ "$rolesFromApiArray_count" == 0 ]; then
      USE_PUT=1
    fi
  fi
}

function deactivate_user_after_delete_if_required() {
  warnSetActiveStateMessage=""

  if [ "$userActiveState" == "true" ]; then
    log_debug "email: ${email} - User activate state=true, de-activating user"
    local body='{"active":false}'
    local submit_response

    submit_response=$(update_user "${userId}" "${body}")
    parse_submit_response "$submit_response"

    if [[ $submit_response =~ .*email.* ]]; then
      log_warn "file: ${filename} , email: ${email} - SUCCESS, user active state set to false"
      isActive="FALSE"
      responseMessage=""
      warnSetActiveStateMessage="WARN: user has been deactivated"
    else
      log_error "file: ${filename} , email: ${email} - FAILED, user active state could not be set to false, API Error: ${responseMessage}"
      responseMessage="WARN: user account is suspended"
      warnSetActiveStateMessage="WARN: failed deactivating user"
    fi
  fi
}

function delete_all_roles_and_deactivate() {
  log_debug "After processing required role deletions, no roles would remain, using PUT to remove ALL roles and then disable the user"

  local submit_response
  local warnSetActiveStateMessage=""
  submit_response=$(put_user_roles "$userId" "[]")
  parse_submit_response "$submit_response"

  if [ "$inviteStatus" == "SUCCESS" ]; then
    deactivate_user_after_delete_if_required

    success_counter=$((success_counter+1))
    lastModified=$(date -u +"%FT%H:%M:%SZ")
    inviteStatus="SUCCESS"
    local reason="All roles were successfully removed from the user"

    if [ "$userActiveState" == "true" ]; then
      echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}$reason${NORMAL}: ${YELLOW}${warnSetActiveStateMessage}"
    else
      echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}$reason${NORMAL}"
    fi

    log_debug "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
    responseMessage="${reason} ${responseMessage} ${warnSetActiveStateMessage}"
  else
    fail_counter=$((fail_counter+1))
    inviteStatus="FAILED"
    local reason="Failed removing all roles"
    echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${responseMessage}${NORMAL}"
    log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason} - ${responseMessage}"
  fi
}

function delete_selected_roles() {
  local addedCounter=0
  local failedToAddCounter=0
  local rolesToRemoveArray_count=${#rolesToRemoveArray[@]}
  local rolesDeleted=()
  local rolesNotDeleted=()
  local csvRole
  local submit_response

  for csvRole in "${rolesToRemoveArray[@]}"; do
    submit_response=$(delete_user_role "$userId" "$csvRole")
    parse_submit_response "$submit_response"

    if [ "$inviteStatus" == "SUCCESS" ]; then
      addedCounter=$((addedCounter+1))
      local reason="role $csvRole successfully removed"
      log_info "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
      rolesDeleted+=("${csvRole}")
    else
      failedToAddCounter=$((failedToAddCounter+1))
      local reason="failed removing role $csvRole"
      log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason} - ${responseMessage}"
      rolesNotDeleted+=("${csvRole}")
    fi
  done

  if [ "$rolesToRemoveArray_count" == 0 ]; then
    skip_record "None of the roles defined are currently assigned to the user"
  elif [ "$failedToAddCounter" -gt 0 ] && [ "$addedCounter" -gt 0 ]; then
    fail_counter=$((fail_counter+1))
    lastModified=$(date -u +"%FT%H:%M:%SZ")
    inviteStatus="PARTIALLY-FAILED"
    local reason="Some roles could not be unassigned, please check logs for further information"
    responseMessage="INFO: Roles successfully removed: ${rolesDeleted[*]} ERROR: Roles failed removal: ${rolesNotDeleted[*]}"
    echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"
    log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
  elif [ "$failedToAddCounter" -eq 0 ] && [ "$addedCounter" -gt 0 ]; then
    success_counter=$((success_counter+1))
    lastModified=$(date -u +"%FT%H:%M:%SZ")
    inviteStatus="SUCCESS"
    local reason="Specified roles were successfully removed from the user"
    responseMessage="INFO: Roles successfully removed: ${rolesDeleted[*]}"
    echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}$reason${NORMAL}"
    log_info "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
  else
    fail_counter=$((fail_counter+1))
    inviteStatus="FAILED"
    local reason="Roles could not be unassigned, please check logs for further information"
    responseMessage="ERROR: $reason"
    echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"
    log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
  fi
}

function handle_delete_roles() {
  log_debug "email: ${email} - User exists, doing deletion logic"

  local USE_PUT
  local default_caseworker_role_provided
  local default_caseworker_role_already_assigned
  local rolesToRemoveArray=()
  local rolesFromApiArray=()

  determine_delete_roles_strategy

  if [ "$userActiveState" == "true" ] || [ "$PROCESS_INACTIVE_USER" = "true" ]; then
    if [ "$USE_PUT" -eq 1 ]; then
      delete_all_roles_and_deactivate
    else
      delete_selected_roles
    fi
  else
    skip_record "${UserExistsNotActive}"
  fi

  build_standard_output_csv "$user"
}

function process_input_file() {
  local filepath_input_original=$1
  local datestamp
  local filepath_input_newpath
  local filepath_output_newpath
  local filepath_input_newpath2
  local filename

  set_processing_file_paths "$filepath_input_original"
  set_log_file_for_input "$filepath_input_original"

  log_debug "****** Start - processing input file ${filepath_input_original}"

  if [[ "$is_test" = true ]]; then
    print_test_file_paths
  fi

  # input file read ok, so move it to backup location
  if json=$(convert_input_file_to_json "${filepath_input_original}"); then

    move_input_file_to_backup
    write_output_header

  # strip JSON into individual items then process in a while loop
  echo "$json" | jq -r -c '.[]' \
      |  \
  ( reset_processing_counters
    while IFS= read -r user; do
      total_counter=$((total_counter+1))

      load_user_record_context "$user"
      log_user_record_start

      if [ "$inviteStatus" != "SUCCESS" ]; then

        lookup_user_for_record
        normalise_roles_from_csv
        warn_about_unused_input_fields

        if ! is_valid_operation; then
          fail_invalid_operation

        elif ! validateEmailAddress "${email}"; then
          fail_invalid_email

        elif roles_csv_is_empty && operation_requires_roles; then
          fail_no_roles_defined

        elif role_string_is_invalid && operation_requires_roles; then
          fail_invalid_role_string

        elif [[ $rawReturnedValue == *"HTTP-"* ]] && [ "$csvSSOId" != "null" ]; then
          fail_sso_user_not_found

        elif [[ $rawReturnedValue == *"HTTP-"* ]] && [ "$operation" == "find" ]; then
          fail_find_user_not_found

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "find" ]; then
          handle_find_user

        elif [ "$operation" == "add" ] && [[ "$ENABLE_USERID_REGISTRATIONS" = true ]]; then
          handle_add_with_userid_registration

        elif [[ $rawReturnedValue == *"HTTP-"* ]] && [ "$operation" == "add" ]; then
          handle_add_new_user

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "deleteuser" ]; then
          handle_delete_user_account

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "suspend" ]; then
          handle_suspend_user

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "unsuspend" ]; then
          handle_unsuspend_user


        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "add" ]; then
          handle_add_roles_to_existing_user

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "updateemail" ]; then
          handle_update_email

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "updatename" ]; then
          handle_update_name

        elif { [[ $rawReturnedValue == *"HTTP-"* ]] && [ "$operation" == "delete" ]; } || [ "$operation" == "updatename" ]; then
          handle_missing_user_for_operation

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "delete" ] && manual_delete_role_requested; then
          fail_manual_role_delete_request

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "delete" ]; then
          handle_delete_roles
        fi

      else
        handle_already_processed_record

      fi

      update_expected_result_counters

      # record log of action in output file (NB: escape values for CSV)
      echo "$output_csv" >> "$filepath_output_newpath"
    done

    log_debug "****** End - processing input file ${filepath_input_original}"

    print_processing_summary
    log_expected_result_summary
  )

else
  echo "$json"

fi

  # copy output file back to original input file location so it can be used for re-run
  # not required as original input directory is now looped through recursively
  # cp "$filepath_output_newpath" "$filepath_input_original" 2> /dev/null
  #if [ $? -eq 0 ]; then
  #  echo "Updated input file to reflect invite status: ${BOLD}${filepath_input_original}${NORMAL}"
  #else
  #  echo "${RED}ERROR: unable to update input file:${NORMAL} ${filepath_input_original}"
  #  exit 1
  #fi
}

function contains() {
    local n=$#
    local value=${!n}
    for ((i=1;i < $#;i++)) {
        if [ "${!i}" == "${value}" ]; then
            echo "y"
            return 0
        fi
    }
    echo "n"
    return 1
}

function removeFromArray {
    local rolesToRemoveArray=$1
    local rolesFromApiArray=$2

    TEMP_ARRAY=()
    for roleToRemove in "${rolesToRemoveArray[@]}"; do
      for roleFromApi in "${rolesFromApiArray[@]}"; do
          KEEP=true
          if [[ ${roleToRemove} == ${roleFromApi} ]]; then
              KEEP=false
              break
          fi
      done
      if ${KEEP}; then
          TEMP_ARRAY+=(${roleToRemove})
      fi
    done
    rolesFromApiArray=("${TEMP_ARRAY[@]}")
    unset TEMP_ARRAY
    echo "${rolesFromApiArray}"
}

function removeFromArray2 {
    rolesFromApiArray=$1
    rolesToRemoveArray=$2

    for removeRole in "${rolesToRemoveArray[@]}"; do
      for i in "${!rolesFromApiArray[@]}"; do
        if [[ ${rolesFromApiArray[i]} = $removeRole ]]; then
          unset 'rolesFromApiArray[i]'
        fi
      done
    done

    #echo "${rolesFromApiArray[@]}"
    echo "${rolesFromApiArray[*]}"
}

function addRolesToCSVRoles {
  local rolesFromCSV=$1
  local strDefaultRoles=$2
  local defaultRolesArray=( $(splitStringToArray "|" "${strDefaultRoles}") )

  #for role in "${defaultRolesArray[@]}"; do
  #  rolesFromCSV=$(echo "${rolesFromCSV}" | jq --arg new "$role" '. += [$new]')
  #done

  for role in "${defaultRolesArray[@]}"; do
    local shouldAdd=1
    for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
        if [ "${csvRole}" == "$role" ]; then
            shouldAdd=0
            break
        fi
    done
    if [ $shouldAdd -eq 1 ]; then
        rolesFromCSV=$(echo "${rolesFromCSV}" | jq --arg new "$role" '. += [$new]')
    fi
  done

  echo "${rolesFromCSV}"
}

# set config value
# usage: set_config IA_ROLES $NEW_IA_ROLES
# where IA_ROLES is the key field, $NEW_IA_ROLES is the new value
function set_config(){
    sudo sed -i "s/^\($1\s*=\s*\).*\$/\1$2/" $CONFIG
}

function addPreDefinedRolesToCSVRoles {
  local rolesFromCSV=$1
  local finalRoles=() #declare empty shell array

  local array=(
      "DIVORCE-ROLES::${DIVORCE_ROLES}"
      "DIVORCE-FR-ROLES::${DIVORCE_FR_ROLES}"
      "EMPLOYMENT-ROLES::${EMPLOYMENT_ROLES}"
      "FR-ROLES::${FR_ROLES}"
      "IA-ROLES::${IA_ROLES}"
      "PRIVATELAW-ROLES::${PRIVATELAW_ROLES}"
      "PUBLICLAW-ROLES::${PUBLICLAW_ROLES}"
      "SSCS-ROLES::${SSCS_ROLES}"
  )

  for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
    if [[ "$csvRole" == *"-roles"* ]]; then
        log_debug "Adding preDefinedRoles"
        local found=0
        csvRoleUpper=$(echo "${csvRole}" | tr '[:lower:]' '[:upper:]')
        for index in "${array[@]}" ; do
            KEY="${index%%::*}"
            VALUE="${index##*::}"
            if [ "${KEY}" = "${csvRoleUpper}" ]; then
                local preDefinedRoles=( $(splitStringToArray "|" $VALUE) )
                for role in "${preDefinedRoles[@]}"; do
                    finalRoles+=("${role}")
                done
                found=1
                break
            fi
        done
        if [ $found -eq 0 ]; then
            log_error "file: ${filename} , ${csvRole} not defined in configuration file"
        fi
    else
        finalRoles+=("${csvRole}")
    fi
  done

  rolesFromCSV=$(printf '%s\n' "${finalRoles[@]}" | jq -R . | jq -s .)
  echo "${rolesFromCSV}"
}

function checkAllowedRole {
  local rolesFromCSV=$1
  local rolesToCheckFor=$2
  local notAllowedRolesArray=( $(splitStringToArray "|" "${rolesToCheckFor}") )

  #echo "Number of elements in the array: ${#notAllowedRolesArray[@]}" >&2

  local notAllowedRoleFound=0

  for role in "${notAllowedRolesArray[@]}"; do
    #echo "role $role" >&2
    for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
      if [ "${csvRole}" == "$role" ]; then
        notAllowedRoleFound=1
        break
      fi
    done
    if [ $notAllowedRoleFound -eq 1 ]; then
      break
    fi
  done

  echo $notAllowedRoleFound
}

function checkArrayContainsStringRole {
    # $1 is ex, IGNORED_ROLES_FROM_USER_DELETE_REQUEST
    local stringArray=( $(splitStringToArray "|" "$1") )
    local roleToCheckFor=$2

    local found=0

    for stringCheck in "${stringArray[@]}"; do
        if [ "$roleToCheckFor" == "${stringCheck}" ]; then
            found=1
            break
        fi
    done

    echo $found
}

function checkJsonContainsStringRole {
  local rolesFromCSV=$1
  local roleToCheckFor=$2

  local found=0

  for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
    if [ "${csvRole}" == "$roleToCheckFor" ]; then
      found=1
      break
    fi
  done

  echo $found
}

function stripNotAllowedRoles {
  local rolesFromCSV=$1
  local rolesToCheckFor=$2
  local notAllowedRolesArray=( $(splitStringToArray "|" "${rolesToCheckFor}") )

  local rolesFromCsvAsArray=()
  local finalRoles=()

  for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
    rolesFromCsvAsArray+=("${csvRole}")
  done

  for role in "${rolesFromCsvAsArray[@]}"; do
    notAllowedRoleFound=0
    for notAllowedRole in "${notAllowedRolesArray[@]}"; do
        if [ "${role}" == "$notAllowedRole" ]; then
            notAllowedRoleFound=1
            break
        fi
    done
    if [ $notAllowedRoleFound -eq 0 ]; then
      finalRoles+=("${role}")
    fi
  done


  if [ ${#finalRoles[@]} -eq 0 ]; then
    rolesFromCSV="[]"
  else
    rolesFromCSV=$(printf '%s\n' "${finalRoles[@]}" | jq -R . | jq -s .)
  fi
  echo "${rolesFromCSV}"
}

function returnNotAllowedRoles {
  local rolesFromCSV=$1
  local rolesToCheckFor=$2
  local notAllowedRolesArray=( $(splitStringToArray "|" "${rolesToCheckFor}") )
  local rolesDiscardedArray=()

  for notAllowedRole in "${notAllowedRolesArray[@]}"; do
    for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
        if [ "${notAllowedRole}" == "$csvRole" ]; then
            rolesDiscardedArray+=("${notAllowedRole}")
        fi
    done
  done

  echo "${rolesDiscardedArray[@]}"
}

function checkShouldAddRole {
  local rolesFromCSV=$1
  local rolesToCheckFor=$2
  local rolesToCheckForArray=( $(splitStringToArray "|" "${rolesToCheckFor}") )

  local countRolesToCheckForArray=${#rolesToCheckForArray[@]}
  local countRolesFromCSV=$(echo $rolesFromCSV | jq -e '. | length');

  local counter=0
  local shouldAdd=1

  for role in "${rolesToCheckForArray[@]}"; do
    for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
      if [ "${csvRole}" == "$role" ]; then
        counter=$((counter+1))
      fi
    done
  done

  #echo "counter $counter" >&2
  #echo "countRolesFromCSV $countRolesFromCSV" >&2

  if [ $counter -eq $countRolesFromCSV ]; then
    shouldAdd=0
  fi

  echo $shouldAdd
}

function checkShouldAddDefaultRoles {
  local rolesFromCSV=$1
  local rolesToCheckForArray=( $(splitStringToArray "|" "${ADD_ROLES_BY_DEFAULT}") )
  local addRolesToIgnoreByDefaultArray=( $(splitStringToArray "|" "${IGNORED_ROLES_FROM_USER_ADD_REQUEST}") )
  local countRolesToCheckForArray=${#rolesToCheckForArray[@]}

  local counter=0
  local shouldAdd=1
  local default_type_role_found=0

  for role in "${rolesToCheckForArray[@]}"; do
    for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
        if [ $(checkArrayContainsStringRole "${IGNORED_ROLES_FROM_USER_ADD_REQUEST}" "${csvRole}") -eq 1 ]; then
            log_debug "Ignoring role ${csvRole}"
        elif [[ "${csvRole}" == *"$role"* ]]; then
            default_type_role_found=1
            break
        fi
    done
    if [ $default_type_role_found -eq 1 ]; then
        break
    fi
  done

  if [ $default_type_role_found -eq 1 ]; then
    for role in "${rolesToCheckForArray[@]}"; do
          for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
            if [ "${csvRole}" == "$role" ]; then
              counter=$((counter+1))
            fi
          done
     done
     if [ $counter -eq $countRolesToCheckForArray ]; then
         shouldAdd=0
     fi
  else
    shouldAdd=0
  fi

  echo $shouldAdd
}

function splitStringToArray {
  delimeter=$1
  theString=$2

  myArray=()

  oldIFS=$IFS
  IFS="${delimeter}"
  #read -ra myArray <<< "${theString}"
  read -r -d '' -a myArray <<< "$theString"
  IFS=$oldIFS
  echo "${myArray[*]}"
}

function convertToLowerCase {
  local strTemp=$1
  strTemp=$(echo "${strTemp}" | tr '[:upper:]' '[:lower:]')
  echo "${strTemp}"
}

function convertJsonStringArrayToLowerCase {
  local rolesFromCSV=$1
  local ARRAY=() #declare empty shell array

  for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
    csvRole=$(convertToLowerCase "${csvRole}")
    #remove white space in between role
    csvRole="${csvRole// /}"
    ARRAY+=("${csvRole}")
  done

  rolesFromCSV=$(printf '%s\n' "${ARRAY[@]}" | jq -R . | jq -s .)

  echo "${rolesFromCSV}"
}

function validateEmailAddress {
  regex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
  local emailAddress=$1

  if [[ $emailAddress =~ $regex ]] ; then
      true
  else
      false
  fi
}

#not used yet
function stripSpecialCharacters {
  local stringInput=$1
  regex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"

  echo "${stringInput//$regex/}"
}

function validateRoleString() {

  local roleString=$1
  local isValidRoleString=1

  if [[ "${roleString}" = *[![:space:]A-Za-z_\|-]* ]]; then
      isValidRoleString=0
  fi

  echo $isValidRoleString
}

#This function is no longer used
#Kept for completeness
function addRequiredMandatoryRole {
  strRole=$1
  rolesFromCSV=$2

  local role_found_in_rolesFromCSV=0
  for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
    if [ $csvRole == "$strRole" ]; then
      role_found_in_rolesFromCSV=1
    fi
  done
  if [ $role_found_in_rolesFromCSV -eq 0 ]; then
    tempString=$(echo $rolesFromCSV | sed -e 's/\[ //g' -e 's/\ ]//g' -e 's/\,//g')
    roles_array=( $tempString )

    roles_array+=("$strRole")

    arr='[]'  # Empty JSON array
    for x in "${roles_array[@]}"; do
      arr=$(jq -n --arg x "${x//\"}" --argjson arr "$arr" '$arr + [$x]')
    done
    rolesFromCSV=$arr
  fi

  echo "$rolesFromCSV"
}

function checkMasterCaseworkerRoles
{
    local masterCaseworkerRoleFile=""

    if [[ "$is_test" = true ]]; then
        masterCaseworkerRoleFile="caseworker-roles-local-testing.txt"
    else
        masterCaseworkerRoleFile="caseworker-roles-master.txt"
    fi

    log_info "Local master caseworker file: ./"${masterCaseworkerRoleFile}""
    printf "%s\n" "Local master caseworker file: ./"${masterCaseworkerRoleFile}""

    IFS=$'\n' read -d '' -r -a caseworkerRolesMasterArray < ./"${masterCaseworkerRoleFile}"

    local rawRolesResponse=$(get_roles)
    local apiCaseworkerRolesBashArray=() #declare empty shell array
    local inLocalNotInRemote=()
    local inRemoteNotInLocal=()
    local FOUND=false

    if [[ $rawRolesResponse != *"HTTP-"* ]]; then
        for rawRoleName in $(echo "${rawRolesResponse}" | jq .[].name); do
            if [[ "$rawRoleName" == *"$ADD_ROLES_BY_DEFAULT"* ]]; then
                #role=$(convertToLowerCase "${rawRoleName}")
                #remove white space in between role
                #role="${role// /}"
                rawRoleName="${rawRoleName%\"}"
                rawRoleName="${rawRoleName#\"}"
                apiCaseworkerRolesBashArray+=("${rawRoleName}")
            fi
        done
    fi

    for caseworkerRoleMaster in "${caseworkerRolesMasterArray[@]}"; do
      for apiCaseWorkerRole in "${apiCaseworkerRolesBashArray[@]}"; do
          FOUND=false
          if [[ "${caseworkerRoleMaster}" == "${apiCaseWorkerRole}" ]]; then
              FOUND=true
              break
          fi
      done
      if [[ "$FOUND" = false ]]; then
          inLocalNotInRemote+=(${caseworkerRoleMaster})
      fi
    done

    for apiCaseWorkerRole in "${apiCaseworkerRolesBashArray[@]}"; do
      for caseworkerRoleMaster in "${caseworkerRolesMasterArray[@]}"; do
          FOUND=false
          if [[ ${apiCaseWorkerRole} == ${caseworkerRoleMaster} ]]; then
              FOUND=true
              break
          fi
      done
      if [[ "$FOUND" = false ]]; then
          inRemoteNotInLocal+=(${apiCaseWorkerRole})
      fi
    done

    #differencesArray=(`echo ${apiRolesBashArray[@]} ${caseworkerRolesMasterArray[@]} | tr ' ' '\n' | sort | uniq -u `)

    #if (( ${#differencesArray[@]} )); then
        #array is not empty
        #echo "${differencesArray[*]}" >&2
        #printf "%s\n\n" "The following roles are not found in local master caseworker role file:"
        #printf "%s\n" "${differencesArray[@]}"
    #fi

    local strInLocalNotInRemote="Local and Remote caseworker roles out of synch, the following local caseworker roles are not found in remote:"
    local strInRemoteNotInLocal="Remote and Local caseworker roles out of sync, the following remote caseworker roles are not found in local file:"
    local strLocalUptoDate="Local and Remote caseworker roles: UP-TO-DATE"
    local strRemoteUptoDate="Remote vs Local caseworker roles: UP-TO-DATE"
    local strHeading="Comparison of local (master file) caseworker roles against remote (API) caseworker roles:"

    #printf "%s\n" "${strHeading}"
    #log_info "${strHeading}"

    if (( ${#inLocalNotInRemote[@]} )); then
        #array is not empty
        printf "%s\n" "${RED}${strInLocalNotInRemote}${NORMAL}"
        printf "%s\n${RED}${NORMAL}" "${inLocalNotInRemote[@]}"

        log_info "${strInLocalNotInRemote}"
        #output array contents as a string for logging
        printf -v tmpVAR "%s\n" "${inLocalNotInRemote[@]}"
        tmpVAR=${tmpVAR%?}
        log_info "${tmpVAR}"
    else
        printf "%s\n" "${GREEN}${strLocalUptoDate}${NORMAL}"
        log_info "${strLocalUptoDate}"
    fi

    if (( ${#inRemoteNotInLocal[@]} )); then
        #array is not empty
        printf "%s\n" "${RED}$strInRemoteNotInLocal${NORMAL}"
        printf "%s\n${RED}${NORMAL}" "${inRemoteNotInLocal[@]}"

        log_info "$strInRemoteNotInLocal"
        #output array contents as a string for logging
        printf -v tmpVAR "%s\n" "${inRemoteNotInLocal[@]}"
        tmpVAR=${tmpVAR%?}
        log_info "${tmpVAR}"
    else
        printf "%s\n" "${GREEN}${strRemoteUptoDate}${NORMAL}"
        log_info "${strRemoteUptoDate}"
    fi
}

function jumpto
{
    label=$1
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}

function trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
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

############################
# Logging Functions - Start
############################

# Logging functions
function log_output {
  #echo `date "+%Y/%m/%d %H:%M:%S"`" $1"
  echo `date "+%Y/%m/%d %H:%M:%S"`" $1" >> "${LOGFILE}"
}

function log_debug {
  if [[ "$LOGLEVEL" =~ ^(DEBUG)$ ]]; then
    log_output "DEBUG $1"
  fi
}

function log_info {
  if [[ "$LOGLEVEL" =~ ^(DEBUG|INFO)$ ]]; then
    log_output "INFO $1"
  fi
}

function log_warn {
  if [[ "$LOGLEVEL" =~ ^(DEBUG|INFO|WARN)$ ]]; then
    log_output "WARN $1"
  fi
}

function log_error {
  if [[ "$LOGLEVEL" =~ ^(DEBUG|INFO|WARN|ERROR)$ ]]; then
    log_output "ERROR $1"
  fi
}
##########################
# Logging Functions - End
##########################

# loop & process any .csv files found
process_folder_recurse() {

  TIMEFORMAT="The input was processed in: %3lR"

  for i in "$1"/*.csv;do
    if [ -f "$i" ]; then
      time process_input_file "${i}"
    fi
  done

  #final task is to check and report on missing caseworker-roles by comparing
  #api results to local master file

}

read -p $'\nPlease enter environment (default is local): ' ENV

ENV=${ENV:-local}

if [ "$ENV" == "local" ]; then
    is_test=true
    if [[ "$CREATE_TEST_USERS" = true ]]; then
        echo "Calling ./test/utils/add-users.sh"
        ./test/utils/add-users.sh
    fi
fi

if [[ "$is_test" = false ]]; then
  # read input arguments
  read -p "Please enter directory path containing csv input files: " CSV_DIR_PATH
  read -p "Please enter ccd idam-admin username: " ADMIN_USER
  ADMIN_USER_PWD=$(read_password_with_asterisk "Please enter ccd idam-admin password: ")
  IDAM_CLIENT_SECRET=$(read_password_with_asterisk $'\nPlease enter idam oauth2 secret for ccd-bulk-user-register client: ')
fi

# Check if a param is set to a valid value
if [[ ! "$LOGLEVEL" =~ ^(DEBUG|INFO|WARN|ERROR)$ ]]; then
  echo "Logging level needs to be DEBUG, INFO, WARN or ERROR."
  exit 1
fi

if [ -z "${CSV_DIR_PATH}" ] || [ -z "${ADMIN_USER}" ] || [ -z "${ADMIN_USER_PWD}" ] || [ -z "${IDAM_CLIENT_SECRET}" ]
then
  echo "${RED}Please provide all required inputs to the script.${NORMAL} Try running again ./bulk-user-creation.sh"
  exit 1
fi

IDAM_URL=$(get_idam_url)
IDAM_ACCESS_TOKEN=$(get_idam_token)
check_exit_code_for_error $? "$IDAM_ACCESS_TOKEN"

if [ -z "$IDAM_ACCESS_TOKEN" ]
then
    echo "${RED}ERROR: Problem getting idam token for admin user:${NORMAL} $ADMIN_USER"
    exit 1
fi

# read csv(s) and call curl in a loop for each record
process_folder_recurse "${CSV_DIR_PATH}"
if [[ "$ENABLE_CASEWORKER_CHECKS" = true ]]; then
    echo "Checking caseworker roles .."
    log_info "Checking caseworker roles .."
    checkMasterCaseworkerRoles
fi

unset https_proxy;
