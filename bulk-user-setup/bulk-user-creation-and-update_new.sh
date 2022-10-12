#!/usr/bin/env bash

#######################################
# Logging Constants / global variables
#######################################
LOGFILE='' #Will be set based on input file
LOGLEVEL='DEBUG'

##########################
# console colours / fonts
##########################
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
is_test=1

###########################################
# Special case Constants / global variables
###########################################
#'|' delimited string of roles. These roles are special roles
#if found in request skip adding the default roles to the user
SPECIAL_ROLES="ccd-import|ccd-admin" #if only this role, then do not add default role below

#'|' delimited string of roles. These roles are default for all and will be added
#if a special role above is not found in the request
DEFAULT_ROLES="caseworker"

#'|' delimited string of roles. These roles should not be processed by this script
MANUAL_ROLES="judiciary"

#####################################
# Operations supported by this script
#####################################
OPS=("add" "updatename" "delete" "find")

function get_idam_url() {
    if [ "$ENV" == "prod" ]
    then
      url="https://idam-api.platform.hmcts.net"
    elif [ "$ENV" == "local" ]
    then
      url="http://localhost:5000"
    else
      url="https://idam-api.${ENV}.platform.hmcts.net"
    fi
    echo "$url"
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
    # then quit with non-zero exit code
    exit $(( http_status ))
  fi
}

function submit_user_registation() {
  local USER=$1

  curl_result=$(
    #/api/v1/users/registration
    curl -w $"\n%{http_code}" --silent -X POST "${IDAM_URL}/api/v1/users/registration" -H "accept: application/json" -H "Content-Type: application/json" \
      -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}" \
      -d "${USER}"
  )

  exit_code=$?
  if [ $exit_code -eq 0 ]; then
    # seperate body and status into an array
    IFS=$'\n' response_array=($curl_result)

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
      response="SUCCESS
      ${response_body}"
    else
      # FAIL:
      response="HTTP-${response_status}
      ${response_body}"
    fi
  else
    # format a response for low level curl error (e.g. exit code 7 = 'Failed to connect() to host or proxy.')
    response="CURL-${exit_code}
    ERROR: User registration request has failed with curl exit code: ${exit_code}"
  fi
  echo "$response"
}

function patch_user_roles() {
  local USERID=$1
  local ROLEID=$2

  curl_result=$(
    curl -w $"\n%{http_code}" --silent -X PATCH "${IDAM_URL}/users/${USERID}/roles/${ROLEID}" -H "accept: application/json" -H "Content-Type: application/json" \
    -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"
  )

  exit_code=$?
  if [ $exit_code -eq 0 ]; then
    # seperate body and status into an array
    IFS=$'\n' response_array=($curl_result)

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
      response="SUCCESS
      ${response_body}"
    else
      # FAIL:
      response="HTTP-${response_status}
      ${response_body}"
    fi
  else
    # format a response for low level curl error (e.g. exit code 7 = 'Failed to connect() to host or proxy.')
    response="CURL-${exit_code}
    ERROR: User ${USER} role update request has failed with curl exit code: ${exit_code}"
  fi
  echo "$response"
}

function post_user_roles() {
  local USER=$1
  local ROLES=$2

  curl_result=$(
    curl -w $"\n%{http_code}" --silent -X POST "${IDAM_URL}/api/v1/users/${USER}/roles" -H "accept: application/json" -H "Content-Type: application/json" \
    -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}" \
    -d "${ROLES}"
  )

  exit_code=$?
  if [ $exit_code -eq 0 ]; then
    # seperate body and status into an array
    IFS=$'\n' response_array=($curl_result)

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
      response="SUCCESS
      ${response_body}"
    else
      # FAIL:
      response="HTTP-${response_status}
      ${response_body}"
    fi
  else
    # format a response for low level curl error (e.g. exit code 7 = 'Failed to connect() to host or proxy.')
    response="CURL-${exit_code}
    ERROR: User ${USER} role update request has failed with curl exit code: ${exit_code}"
  fi
  echo "$response"
}

function delete_user_role() {
  #Removes a role from the user

  local USER=$1
  local ROLE=$2

  curl_result=$(
    curl -w $"\n%{http_code}" --silent -X DELETE "${IDAM_URL}/api/v1/users/${USER}/roles/${ROLE}" -H "accept: application/json" -H "Content-Type: application/json" \
    -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"
  )

  exit_code=$?
  if [ $exit_code -eq 0 ]; then
    # seperate body and status into an array
    IFS=$'\n' response_array=($curl_result)

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
      response="SUCCESS
      ${response_body}"
    else
      # FAIL:
      response="HTTP-${response_status}
      ${response_body}"
    fi
  else
    # format a response for low level curl error (e.g. exit code 7 = 'Failed to connect() to host or proxy.')
    response="CURL-${exit_code}
    ERROR: User ${USER} role update request has failed with curl exit code: ${exit_code}"
  fi
  echo "$response"
}

function put_user_roles() {
  #Replaces the entire set of role grants to the user

  local USER=$1
  local ROLES=$2

  curl_result=$(
    curl -w $"\n%{http_code}" --silent -X PUT "${IDAM_URL}/api/v1/users/${USER}/roles" -H "accept: application/json" -H "Content-Type: application/json" \
    -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}" \
    -d "${ROLES}"
  )

  exit_code=$?
  if [ $exit_code -eq 0 ]; then
    # seperate body and status into an array
    IFS=$'\n' response_array=($curl_result)

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
      response="SUCCESS
      ${response_body}"
    else
      # FAIL:
      response="HTTP-${response_status}
      ${response_body}"
    fi
  else
    # format a response for low level curl error (e.g. exit code 7 = 'Failed to connect() to host or proxy.')
    response="CURL-${exit_code}
    ERROR: User ${USER} role update request has failed with curl exit code: ${exit_code}"
  fi
  echo "$response"
}

function get_user_api_v1() {
  local EMAIL=$1
  EMAIL="email%3A%20%22$EMAIL%22"

  curl_result=$(
    curl -w $"\n%{http_code}" --silent -X GET -G "${IDAM_URL}/api/v1/users?query=$EMAIL" -H "accept: */*" -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"
  )

  exit_code=$?
  if [ $exit_code -eq 0 ]; then
    # seperate body and status into an array
    IFS=$'\n' response_array=($curl_result)

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
      response=${response_body}
    else
      # FAIL:
      response="HTTP-${response_status}
      ${response_body}"
      echo "HTTP-${response_status}
      ERROR: Request for UserID with email address ${EMAIL} failed with http response: HTTP-${response_status}"
    fi
  else
    # format a response for low level curl error (e.g. exit code 7 = 'Failed to connect() to host or proxy.')
    response="CURL-${exit_code}
    ERROR: Request for UserID with email address ${EMAIL} failed with curl exit code: ${exit_code}"
  fi
  echo "$response"

}

function get_user() {
  local EMAIL=$1

  #echo $IDAM_URL
  #echo ${IDAM_ACCESS_TOKEN}

  curl_result=$(
    curl -w $"\n%{http_code}" --silent -X GET "${IDAM_URL}/users?email=${EMAIL}" -H "accept: */*" -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"
  )

  exit_code=$?
  if [ $exit_code -eq 0 ]; then
    # seperate body and status into an array
    IFS=$'\n' response_array=($curl_result)

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
      response=${response_body}
    else
      # FAIL:
      response="HTTP-${response_status}
      ${response_body}"
      echo "HTTP-${response_status}
      ERROR: Request for UserID with email address ${EMAIL} failed with http response: HTTP-${response_status}"
    fi
  else
    # format a response for low level curl error (e.g. exit code 7 = 'Failed to connect() to host or proxy.')
    response="CURL-${exit_code}
    ERROR: Request for UserID with email address ${EMAIL} failed with curl exit code: ${exit_code}"
  fi
  echo "$response"

}


function get_user_roles() {
  local USERID=$1

  curl_result=$(
    curl -w $"\n%{http_code}" --silent -X GET "${IDAM_URL}/api/v1/users/${USERID}" -H "accept: */*" -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"
  )

  exit_code=$?
  if [ $exit_code -eq 0 ]; then

    # seperate body and status into an array
    IFS=$'\n' response_array=($curl_result)

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
      response=${response_body}
    else
      # FAIL:
      response="HTTP-${response_status}
      ${response_body}"
      echo "HTTP-${response_status}
      ERROR: Request for roles of user UserID ${USERID} failed with http response: HTTP-${response_status}"
    fi
  else
    # format a response for low level curl error (e.g. exit code 7 = 'Failed to connect() to host or proxy.')
    response="CURL-${exit_code}
    ERROR: Request for roles of user UserID ${USERID} failed with curl exit code: ${exit_code}"
  fi
  echo "$response"

}

function update_user() {
  local USERID=$1
  local USERBODY=$2

  curl_result=$(
    curl -w $"\n%{http_code}" --silent -X PATCH "${IDAM_URL}/api/v1/users/${USERID}" -H "accept: application/json" -H "Content-Type: application/json" \
    -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}" \
    -d "${USERBODY}"
  )

  exit_code=$?
  if [ $exit_code -eq 0 ]; then

    # seperate body and status into an array
    IFS=$'\n' response_array=($curl_result)

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
      response=${response_body}
    else
      # FAIL:
      response="HTTP-${response_status}
      ${response_body}"
      echo "HTTP-${response_status}
      ERROR: Request for update_user of user UserID ${USERID} failed with http response: HTTP-${response_status}"
    fi
  else
    # format a response for low level curl error (e.g. exit code 7 = 'Failed to connect() to host or proxy.')
    response="CURL-${exit_code}
    ERROR: Request for update_user of user UserID ${USERID} failed with curl exit code: ${exit_code}"
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
    exit 99
  fi

  ## verify JSON format by checking JUST THE FIRST ITEM has the required field
  if [ $(echo $json | jq "first(.[] | has(\"${field}\"))") == false ]; then
    echo "${RED}ERROR: Field not found in input:${NORMAL} ${field}"
    exit 99
  fi
}

function generate_csv_path_with_insert() {
  local original_filename=$1
  local insert=$2

  #CSV_PROCESSED_DIR_PATH

  local dirname=$(dirname "${original_filename}")
  local basename=$(basename "${original_filename}")
  local filename="${basename%.*}"
  local extension="${basename##*.}"

  # add default CSV extension if none was found
  if [ "$extension" = "" ] || [ "$filename" = "$basename" ]; then
    extension="csv"
  fi

  if [[ ! -e "${dirname}/${CSV_PROCESSED_DIR_NAME}" ]]; then
    mkdir "${dirname}/${CSV_PROCESSED_DIR_NAME}"
  fi
  echo "${dirname}/${CSV_PROCESSED_DIR_NAME}/${filename}.${insert}.${extension}"
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
    mkdir "${dirname}/${CSV_PROCESSED_DIR_NAME}"
  fi

  echo "${dirname}/${CSV_PROCESSED_DIR_NAME}/${filename}.${insert}.${extension}"
}

function convert_input_file_to_json() {
  local file=$1

  verify_csv_tools_are_available

  verify_file_exists "$file"

  # read from CSV by using CSVJSON
  local raw_csv_as_json=$(csvjson --datetime-format "." "$file")

  # verify JSON format  (ie. check mandatory fields are present)
  verify_json_format_includes_field "${raw_csv_as_json}" "operation"
  verify_json_format_includes_field "${raw_csv_as_json}" "email"
  verify_json_format_includes_field "${raw_csv_as_json}" "firstName"
  verify_json_format_includes_field "${raw_csv_as_json}" "lastName"
  verify_json_format_includes_field "${raw_csv_as_json}" "roles"

  #"roles": (try(.roles | split("|") | walk( if type == "string" then (sub("^[[:space:]]+"; "") | sub("[[:space:]]+$"; "")) else . end)) // null),

  # then reformat JSON using JQ
  local input_as_json=$(echo $raw_csv_as_json \
    | jq -r -c 'map({
        "idamUser": {
          "email": .email,
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
          "idamResponse": .idamResponse,
          "idamUserJson": .idamUserJson,
          "timestamp": .timestamp
        }
      })' ) # NB: extraCsvData element included in JSON to help preserve csv data when skipping an already complete record (i.e. inviteStatus="success")

  echo "$input_as_json"
}

function process_input_file() {
  local filepath_input_original=$1

  # generate new paths for input and output files
  local datestamp=$(date -u +"%FT%H%M%SZ")
  local filepath_input_newpath=$(generate_csv_path_with_insert "$filepath_input_original" "${datestamp}_INPUT")
  local filepath_output_newpath=$(generate_csv_path_with_insert "$filepath_input_original" "${datestamp}_OUTPUT")

  local datestamp_day=$(date -u +"%F")
  LOGFILE="$(generate_log_path_with_insert "$filepath_input_original" "${datestamp_day}_LOG")"

  log_info "Processing input file ${filepath_input_original}"

  if [ $is_test -eq 1 ]; then
    echo 'Test outputs of resulting files!'
    echo $filepath_input_original
    echo $filepath_input_newpath
    echo $filepath_output_newpath
    echo $IDAM_ACCESS_TOKEN
  fi

  # convert input file to json
  json=$(convert_input_file_to_json "${filepath_input_original}")
  check_exit_code_for_error $? "$json"

  if [ $is_test -eq 0 ]; then
    # input file read ok ...
    # ... so move it to backup location
    mv "$filepath_input_original" "$filepath_input_newpath" 2> /dev/null
    if [ $? -eq 0 ]; then
      echo "Moved input file to backup location: ${BOLD}${filepath_input_newpath}${NORMAL}"
    else
      echo "${RED}ERROR: Aborted as unable to move input file to backup location:${NORMAL} ${filepath_input_original}"
      exit 1
    fi
    # write headers to output file
    echo "operation,email,firstName,lastName,roles,status,idamResponse,idamUserJson,timestamp" >> "$filepath_output_newpath"
  fi

  # write headers to output file
  echo "operation,email,firstName,lastName,roles,status,idamResponse,idamUserJson,timestamp" >> "$filepath_output_newpath"

  # strip JSON into individual items then process in a while loop
  echo $json | jq -r -c '.[]' \
      |  \
  ( success_counter=0;skipped_counter=0;fail_counter=0;total_counter=0;
    while IFS= read -r user; do
      total_counter=$((total_counter+1))

      # extract CSV fields from json to use in output
      local email=$(echo $user | jq --raw-output '.idamUser.email')
      email=$(trim "$email") #trim leading and trailing spaces from email string

      local firstName=$(echo $user | jq --raw-output '.idamUser.firstName')
      firstName=$(trim "$firstName") #trim leading and trailing spaces from firstname string

      local lastName=$(echo $user | jq --raw-output '.idamUser.lastName')
      lastName=$(trim "$lastName") #trim leading and trailing spaces from lastName string

      local operation=$(echo $user | jq --raw-output '.extraCsvData.operation')
      operation=$(trim "$operation")
      operation=$(convertToLowerCase "$operation")

      # leading and trailing spaces between roles is taken care in the function call to convert_input_file_to_json
      local rolesFromCSV=$(echo $user | jq --raw-output '.idamUser.roles')

      # load formatted user JSON ready to send to IDAM
      local idamUserJson=$(echo $user | jq -c --raw-output '.idamUser')

      #inviteStatus from input CSV can take value SUCCESS
      #required so we do not send another registration request if one is already pending
      local inviteStatus=$(echo $user | jq --raw-output '.extraCsvData.status')

      log_debug "processing user with email: ${email}"

      if [ "$inviteStatus" != "SUCCESS" ]; then
        # regardless if operation (add/remove) we should always check if the user already exists or not
        local rawReturnedValue=$(get_user "$email")
        #local rawReturnedValue=$(get_user_api_v1 "${email}")

        if [[ $rawReturnedValue != *"HTTP-"* ]]; then
          local userId=$(echo $rawReturnedValue | jq --raw-output '.id')
          #local userId=$(echo $$rawReturnedValue | jq '.[]' | jq --slurp '.[0]' | jq --raw-output '.id')

          local userActiveState=$(echo $rawReturnedValue | jq --raw-output '.active') # i.e. ACTIVE
          #local userActiveState=$(echo $$rawReturnedValue | jq '.[]' | jq --slurp '.[0]' | jq --raw-output '.active')

          #local userRecordType=$(echo $userObject | jq --raw-output '.recordType') # i.e. LIVE

          local firstNameFromApi=$(echo $rawReturnedValue | jq --raw-output '.forename')
          #local firstNameFromApi=$(echo $$rawReturnedValue | jq '.[]' | jq --slurp '.[0]' | jq --raw-output '.forename')

          local lastNameFromApi=$(echo $rawReturnedValue | jq --raw-output '.surname')
          #local lastNameFromApi=$(echo $$rawReturnedValue | jq '.[]' | jq --slurp '.[0]' | jq --raw-output '.surname')

          local rawUserRoles=$(get_user_roles "$userId" )
          local usersRolesFromApi=$(echo $rawUserRoles | jq --raw-output '.roles')

          log_debug "email: ${email}"
          log_debug "user_id: ${userId}"
          log_debug "roles from API call: ${usersRolesFromApi}"
        fi

        log_debug "original roles from CSV: ${rolesFromCSV}"

        if [ $(echo $rolesFromCSV | jq -e '. | length') != 0 ]; then
          rolesFromCSV=$(convertJsonStringArrayToLowerCase "${rolesFromCSV}")
          log_debug "original roles from CSV (in lower case): ${rolesFromCSV}"
        fi

        if [ $(contains "${OPS[@]}" "${operation}") == "n" ]; then

          # SKIP:
          skipped_counter=$((skipped_counter+1))
          inviteStatus="SKIPPED"
          local reason="Operation '${operation}' not recognised, valid operations are: ${OPS[@]}"
          idamResponse=$reason
          log_info "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
          echo "${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${reason}${NORMAL}"

        elif ! $(validateEmailAddress "${email}"); then

          fail_counter=$((fail_counter+1))
          local reason="Invalid email detected, skipping line"
          idamResponse=$reason
          inviteStatus="FAILED"
          log_error "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
          echo "${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$inviteStatus\",\"${idamResponse//\"/\"\"}\",\"${idamUserJson//\"/\"\"}\",\"$timestamp\""

        elif [[ $rawReturnedValue == *"HTTP-"* ]] && [ "$operation" == "find" ]; then

            fail_counter=$((fail_counter+1))
            local reason="user not found"
            idamResponse=$reason
            inviteStatus="FAILED"
            log_error "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
            echo "${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"

            # prepare output (NB: escape generated values for CSV)
            input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
            timestamp=$(date -u +"%FT%H:%M:%SZ")
            output_csv="$input_csv,\"$inviteStatus\",\"${idamResponse//\"/\"\"}\",\"${idamUserJson//\"/\"\"}\",\"$timestamp\""

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "find" ]; then
            local api_v1_user=$(get_user_api_v1 "${email}")

            if [[ $api_v1_user != *"HTTP-"* ]]; then
              # SUCCESS:
              success_counter=$((success_counter+1))
              local reason="user details successfully retrieved"
              idamResponse=$api_v1_user
              inviteStatus="SUCCESS"
              log_info "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
              echo "${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}${reason}${NORMAL}"

              # prepare output (NB: escape generated values for CSV)
              input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
              timestamp=$(date -u +"%FT%H:%M:%SZ")
              output_csv="$input_csv,\"$inviteStatus\",\"${idamResponse//\"/\"\"}\",\"${idamUserJson//\"/\"\"}\",\"$timestamp\""
            else
              fail_counter=$((fail_counter+1))
              local reason="user not found using api/v1/users?query=email:"${email}" endpoint"
              idamResponse=$reason
              inviteStatus="FAILED"
              log_error "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
              echo "${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"

              # prepare output (NB: escape generated values for CSV)
              input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
              timestamp=$(date -u +"%FT%H:%M:%SZ")
              output_csv="$input_csv,\"$inviteStatus\",\"${idamResponse//\"/\"\"}\",\"${idamUserJson//\"/\"\"}\",\"$timestamp\""
            fi

        elif [[ $rawReturnedValue == *"HTTP-"* ]] && [ "$operation" == "add" ]; then

          log_debug "email: ${email} - User does not exist, sending invite registration"

          if [ $(echo $rolesFromCSV | jq -e '. | length') == 0 ]; then
            # FAIL:
            fail_counter=$((fail_counter+1))
            local reason="No roles defined, skipping line"
            idamResponse=$reason
            inviteStatus="FAILED"
            log_error "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
            echo "${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"
          else
            if [ $(checkAllowedRole "${rolesFromCSV}" "${MANUAL_ROLES}") -eq 1 ]; then
              # FAIL:
              fail_counter=$((fail_counter+1))
              local reason="One or more roles defined cannot be assigned using this script"
              idamResponse=$reason
              inviteStatus="FAILED"
              log_error "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
              echo "${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"
            else
              if [ $(checkShouldAddRole "${rolesFromCSV}" "${SPECIAL_ROLES}") -eq 1 ]; then
                log_debug "Adding default roles"
                rolesFromCSV=$(addRolesToCSVRoles "${rolesFromCSV}" "${DEFAULT_ROLES}")
              else
                log_debug "Skipping addition of default roles"
              fi

              log_debug "Final roles to apply: ${rolesFromCSV}"

              #Need to update the roles in idamUserJson
              idamUserJson=$(echo $idamUserJson | jq --argjson rolesFromCSV "${rolesFromCSV}" '.roles = $rolesFromCSV')

              log_debug "idamUserJson: ${idamUserJson}"

              # make call to IDAM
              submit_response=$(submit_user_registation "$idamUserJson")

              # seperate submit_user_registation reponse
              IFS=$'\n'
              local response_array=($submit_response)
              local inviteStatus=${response_array[0]}
              local idamResponse=${response_array[1]}

              if [ $inviteStatus == "SUCCESS" ]; then
                # SUCCESS:
                success_counter=$((success_counter+1))
                local reason="user successfully registered"
                log_info "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
                echo "${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}${reason}${NORMAL}"
              else
                # FAIL:
                fail_counter=$((fail_counter+1))
                local reason="failed registering user"
                inviteStatus="FAILED"
                log_error "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason} - ${idamResponse}"
                echo "${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${idamResponse}${NORMAL}"
              fi
            fi
          fi

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$inviteStatus\",\"${idamResponse//\"/\"\"}\",\"${idamUserJson//\"/\"\"}\",\"$timestamp\""

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "add" ]; then

          log_debug "email: ${email} - User exists, doing role addition logic"

          if [ $(echo $rolesFromCSV | jq -e '. | length') == 0 ]; then
            # FAIL:
            fail_counter=$((fail_counter+1))
            local reason="No roles defined, processes terminated"
            idamResponse=$reason
            inviteStatus="FAILED"
            log_error "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
            echo "${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"
          else
            if [ $(checkAllowedRole "${rolesFromCSV}" "${MANUAL_ROLES}") -eq 1 ]; then
              # FAIL:
              fail_counter=$((fail_counter+1))
              local reason="One or more roles defined. cannot be assigned using this script"
              idamResponse=$reason
              inviteStatus="FAILED"
              log_error "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
              echo "${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"
            else
              #Set user activate state to true if false
              if [ $userActiveState == "false" ]; then
                log_info "email: ${email} - User activate state=false, activating user"
                #user activate state is false, need to call patch user api to set to true first
                #note, update_user is a PATCH call, but we cannot modify any roles using this endpoint
                body='{"active":true}'
                submit_response=$(update_user "${userId}" "${body}")

                if [[ "$submit_response" == *"$email"* ]]; then
                  log_info "email: ${email} - SUCCESS, user active state set to true"
                else
                  log_info "email: ${email} - FAILED, user active state could not be set"
                fi
              fi

              combinedCsvApiRoles=$(echo $rolesFromCSV $usersRolesFromApi | jq '.[]' | jq -s)

              if [ $(checkShouldAddRole "${rolesFromCSV}" "${SPECIAL_ROLES}") -eq 1 ]; then
                log_debug "Adding default roles"
                rolesFromCSV=$(addRolesToCSVRoles "${rolesFromCSV}" "${DEFAULT_ROLES}")
              else
                log_debug "Skipping addition of default roles"
              fi

              ARRAY=() #declare empty shell array

              #start - logic to add only the unique roles in csv by comparing already assigned roles
              for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
                local found=0
                for apiRole in $(echo "${usersRolesFromApi}" | jq -r '.[]'); do
                  if [ $csvRole == $apiRole ]; then
                    found=1
                    log_debug "email: ${email}, role: $csvRole  - already assigned"
                  fi
                done
                if [ $found -eq 0 ]; then
                  #Convert to lower-case if required
                  csvRole=$(convertToLowerCase "${csvRole}")
                  log_debug "email: ${email}, role: $csvRole  - Unique (TO BE ADDED)"
                  #Add unique role to be added to bash array
                  ARRAY+=("${csvRole}")
                fi
              done
              #echo "Bash array of unique roles is (CALC): " ${ARRAY[*]}
              #end - logic to add only the unique roles in csv by comparing already assigned roles

              arr='[]'  # Empty JSON array
              for x in "${ARRAY[@]}"; do
                arr=$(jq -n --arg x "$x" --argjson arr "$arr" '$arr + [$x]')
              done

              uniqueRolesJson=$(echo ${arr} | jq 'map( {"name" : . } ) | unique')
              #echo "JSON array of unique roles is (CALC): " $uniqueRolesJson

              log_debug "Final roles to apply: ${uniqueRolesJson}"

              if [ "${uniqueRolesJson}" != "[]" ]; then
                # make call to IDAM to update roles for existing user
                submit_response=$(post_user_roles "$userId" "$uniqueRolesJson")
                #echo $submit_response

                # seperate submit_response reponse
                IFS=$'\n'
                local response_array=($submit_response)
                local inviteStatus=${response_array[0]}
                local idamResponse=${response_array[1]}
                if [ $inviteStatus == "SUCCESS" ]; then
                  # SUCCESS:
                  success_counter=$((success_counter+1))
                  inviteStatus="SUCCESS"
                  local reason="role(s) successfully assigned"
                  echo "${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}$reason - ${idamResponse}${NORMAL}"
                  log_info "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
                else
                  # FAIL:
                  fail_counter=$((fail_counter+1))
                  inviteStatus="FAILED"
                  local reason="failed assigning one or more roles"
                  echo "${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${idamResponse}${NORMAL}"
                  log_error "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason} - ${idamResponse}"
                fi
              else
                # SKIP:
                skipped_counter=$((skipped_counter+1))
                inviteStatus="SKIPPED"
                local reason="required roles are already assigned, no role amendments required"
                idamResponse=$reason
                log_info "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
                echo "${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${reason}${NORMAL}"
              fi
            fi
          fi

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$inviteStatus\",\"${idamResponse//\"/\"\"}\",\"${idamUserJson//\"/\"\"}\",\"$timestamp\""

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "updatename" ]; then

          log_debug "email: ${email} - User exists, doing update firstname lastname logic"

          #check if any roles are specified, if so reject the input string
          if [ $(echo $rolesFromCSV | jq -e '. | length') == 0 ]; then
            #Set user activate state to true if false
            if [ $userActiveState == "false" ]; then
              log_info "email: ${email} - User activate state=false, activating user"
              #user activate state is false, need to call patch user api to set to true first
              #note, update_user is a PATCH call, but we cannot modify any roles using this endpoint
              body='{"active":true}'
              submit_response=$(update_user "${userId}" "${body}")

              if [[ "$submit_response" == *"$email"* ]]; then
                log_info "email: ${email} - SUCCESS, user active state set to true"
              else
                log_info "email: ${email} - FAILED, user active state could not be set"
              fi
            fi

            if [ "${firstName}" != "${firstNameFromApi}" ] || [ "$lastName" != "${lastNameFromApi}" ]; then
              log_info "email: ${email} - doing firstname/lastname update"
              body='{"forename": "'${firstName}'","surname": "'${lastName}'"}'
              submit_response=$(update_user "${userId}" "${body}")

              # seperate submit_response reponse
              IFS=$'\n'
              local response_array=($submit_response)
              local inviteStatus=${response_array[0]}
              local idamResponse=${response_array[1]}
              if [[ "$submit_response" == *"$email"* ]]; then
                # SUCCESS:
                success_counter=$((success_counter+1))
                inviteStatus="SUCCESS"
                local reason="user firstname/lastname successfully updated"
                log_info "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
                echo "${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}${reason}${NORMAL}"
              else
                # FAIL:
                fail_counter=$((fail_counter+1))
                inviteStatus="FAILED"
                local reason="failed updating user firstname/lastname"
                log_error "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
                echo "${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${idamResponse}${NORMAL}"
              fi
            else
              # SKIP:
              skipped_counter=$((skipped_counter+1))
              inviteStatus="SKIPPED"
              idamResponse=$reason
              local reason="no changes in firstname/lastname detected, nothing to update"
              log_info "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
              echo "${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${reason}${NORMAL}"
            fi
          else
            # FAIL:
            fail_counter=$((fail_counter+1))
            inviteStatus="FAILED"
            local reason="roles should not be specified for an update operation"
            idamResponse=$reason
            log_error "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
            echo "${total_counter}: ${email}: ${RED}FAILED${NORMAL}: Status == ${RED}${reason}${NORMAL}"
          fi

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$inviteStatus\",\"${idamResponse//\"/\"\"}\",\"${idamUserJson//\"/\"\"}\",\"$timestamp\""

        elif [[ $rawReturnedValue == *"HTTP-"* ]] && [ "$operation" == "delete" ] || [ "$operation" == "updatename" ]; then

          skipped_counter=$((skipped_counter+1))
          inviteStatus="SKIPPED"
          local reason="User does not exist, cannot process $operation operation"
          idamResponse=$reason
          log_warn "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
          echo "${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${reason}${NORMAL}"

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$inviteStatus\",\"${idamResponse//\"/\"\"}\",\"${idamUserJson//\"/\"\"}\",\"$timestamp\""

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "delete" ]; then

          echo "User exists, processing deletion login"
          #TO DO

          #if (user available and active) {
          #remove all the specified roles (ignoring caseworker role)
          #if (user has only caseworker role)
          #{ remove caseworker role change the user status to inactive }
          #}

          if [ $userActiveState == "true" ]; then
            #delete /api/v1/users/{userId}/roles/{roleName}
            # returns 204 if successful
            # 412 if failed
            #The role provided is not assigned to the user.
            #One or more of the roles provided does not exist.
            local addedCounter=0
            local failedToAddCounter=0

            skipped_counter=$((skipped_counter+1))
            for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
              # make call to IDAM to update roles for existing user
              submit_response=$(delete_user_role "$userId" "$csvRole")

              # seperate submit_response reponse
              IFS=$'\n'
              local response_array=($submit_response)
              local inviteStatus=${response_array[0]}
              local idamResponse=${response_array[1]}

              if [ $inviteStatus == "SUCCESS" ]; then
                addedCounter=$((addedCounter+1))
                local reason="role $csvRole successfully removed"
                log_info "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
              else
                # FAIL:
                failedToAddCounter=$((failedToAddCounter+1))
                local reason="failed removing role $csvRole"
                log_error "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason} - ${idamResponse}"
              fi

            done
          else
            # SKIP:
            inviteStatus="User exists but not active"
            skipped_counter=$((skipped_counter+1))
            echo "${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${inviteStatus}${NORMAL}"
            inviteStatus="SKIPPED"
            idamResponse="User exists but not active"
          fi

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$inviteStatus\",\"${idamResponse//\"/\"\"}\",\"${idamUserJson//\"/\"\"}\",\"$timestamp\""

        fi

      else

        # SKIP:
        skipped_counter=$((skipped_counter+1))
        local reason="Request already processed previously"
        idamResponse=$reason
        echo "${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${inviteStatus} - ${reason}${NORMAL}"
        log_info "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
        # prepare output
        input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
        timestamp=$(date -u +"%FT%H:%M:%SZ")
        output_csv="$input_csv,\"$inviteStatus\",\"${idamResponse//\"/\"\"}\",\"${idamUserJson//\"/\"\"}\",\"$timestamp\""

      fi

      # record log of action in output file (NB: escape values for CSV)
      echo "$output_csv" >> "$filepath_output_newpath"
    done
    echo "Process is complete: ${GREEN}success: ${success_counter}${NORMAL}, ${YELLOW}skipped: ${skipped_counter}${NORMAL}, ${RED}fail: ${fail_counter}${NORMAL}, total: ${total_counter}"
  )

  if [ $is_test -eq 0 ]; then
    # copy output file back to original input file location so it can be used for re-run
    cp "$filepath_output_newpath" "$filepath_input_original" 2> /dev/null
    if [ $? -eq 0 ]; then
      echo "Updated input file to reflect invite status: ${BOLD}${filepath_input_original}${NORMAL}"
    else
      echo "${RED}ERROR: unable to update input file:${NORMAL} ${filepath_input_original}"
      exit 1
    fi
  fi
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

function addRolesToCSVRoles {
  local rolesFromCSV=$1
  local strDefaultRoles=$2
  local defaultRolesArray=( $(splitStringToArray "|" "${strDefaultRoles}") )

  for role in "${defaultRolesArray[@]}"; do
    rolesFromCSV=$(echo "${rolesFromCSV}" | jq --arg new "$role" '. += [$new]')
  done

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

function splitStringToArray {
  delimeter=$1
  theString=$2

  oldIFS="$IFS"
  IFS="${delimeter}"
  read -ra myArray <<< "${theString}"
  IFS="$oldIFS"
  echo "${myArray[@]}"
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
}

if [ $is_test -eq 1 ]
then
  CSV_FILE_PATH="/Users/dineshpatel/Sandbox/CCD_Projects/ccd-docker/bulk-user-setup/Sample input file.csv"
  ADMIN_USER="idamOwner@hmcts.net"
  ADMIN_USER_PWD="Ref0rmIsFun"
  IDAM_CLIENT_SECRET="anything"
  ENV="local"
  CSV_DIR_PATH="/Users/dineshpatel/Sandbox/CCD_Projects/ccd-docker/bulk-user-setup/bulk_processing"
  CSV_PROCESSED_DIR_NAME="Output_$(date -u +"%F")"
else
  # read input arguments
  read -p "Please enter directory path containing csv input files: " CSV_DIR_PATH
  read -p "Please enter ccd idam-admin username: " ADMIN_USER
  ADMIN_USER_PWD=$(read_password_with_asterisk "Please enter ccd idam-admin password: ")
  IDAM_CLIENT_SECRET=$(read_password_with_asterisk $'\nPlease enter idam oauth2 secret for ccd-bulk-user-register client: ')
  read -p $'\nPlease enter environment default [prod]: ' ENV
fi

# Check if a param is set to a valid value
if [[ ! "$LOGLEVEL" =~ ^(DEBUG|INFO|WARN|ERROR)$ ]]; then
  echo "Logging level needs to be DEBUG, INFO, WARN or ERROR."
  exit 1
fi

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
#TIMEFORMAT="The input file(s) were/was processed in: %3lR"
#time process_input_file "${CSV_FILE_PATH}"

process_folder_recurse "${CSV_DIR_PATH}"
unset https_proxy;