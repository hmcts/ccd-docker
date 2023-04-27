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
  #?query=email:"james.bond@hmcts.net"
  local ES_EMAIL_QUERY="email%3A%22${EMAIL}%22"

  curl_result=$(
    curl -w $"\n%{http_code}" --silent -X GET -G "${IDAM_URL}/api/v1/users?query=${ES_EMAIL_QUERY}" -H "accept: */*" -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"
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

function get_user_by_id() {
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

function get_roles() {

  curl_result=$(
    curl -w $"\n%{http_code}" --silent -X GET "${IDAM_URL}/roles" -H "accept: */*" -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}"
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
      ERROR: Request for get roles failed with http response: HTTP-${response_status}"
    fi
  else
    # format a response for low level curl error (e.g. exit code 7 = 'Failed to connect() to host or proxy.')
    response="CURL-${exit_code}
    ERROR: Request for get roles failed with curl exit code: ${exit_code}"
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

function process_input_file() {
  local filepath_input_original=$1

  # generate new paths for input and output files
  local datestamp=$(date -u +"%FT%H%M%SZ")
  local filepath_input_newpath=$(generate_csv_path_with_insert "$filepath_input_original" "_Input_${datestamp}")
  local filepath_output_newpath=$(generate_csv_path_with_insert "$filepath_input_original" "_Output_${datestamp}")
  local filename=$(get_file_name_from_csv_path "$filepath_input_original")

  if [[ "$LOG_PER_INPUT_FILE" = true ]]; then
    LOGFILE="$(generate_log_path_with_insert "$filepath_input_original" "${datestamp}")"
  else
    local datestamp_day=$(date -u +"%F")
    LOGFILE="$(generate_log_path_with_insert "$filepath_input_original" "${datestamp_day}")"
  fi

  log_debug "****** Start - processing input file ${filepath_input_original}"

  if [[ "$is_test" = true ]]; then
    echo 'Test outputs of resulting files!'
    echo $filepath_input_original
    echo $filepath_input_newpath
    echo $filepath_output_newpath
    echo $IDAM_ACCESS_TOKEN
  fi

  # convert input file to json
  json=$(convert_input_file_to_json "${filepath_input_original}")

  # check_exit_code_for_error $? "$json"

  # input file read ok ...
  # ... so move it to backup location
  if [ $? -eq 0 ]; then

    #if [[ "$is_test" = false ]]; then
       mv "$filepath_input_original" "$filepath_input_newpath" 2> /dev/null
        if [ $? -eq 0 ]; then
          echo "Moved input file to backup location: ${BOLD}${filepath_input_newpath}${NORMAL}"
        else
         echo "${RED}ERROR: Aborted as unable to move input file to backup location:${NORMAL} ${filepath_input_newpath}"
         exit 1
        fi
    #fi

    # write headers to output file
    echo "operation,email,firstName,lastName,roles,isActive,lastModified,ssoID,status,responseMessage" >> "$filepath_output_newpath"

  # strip JSON into individual items then process in a while loop
  echo $json | jq -r -c '.[]' \
      |  \
  ( success_counter=0;skipped_counter=0;fail_counter=0;total_counter=0;test_pass_counter=0;test_fail_counter=0
    while IFS= read -r user; do
      total_counter=$((total_counter+1))

      local isActive=" "
      local lastModified=" "
      local outputSSOId=" "

      # extract CSV fields from json to use in output
      local email=$(echo $user | jq --raw-output '.idamUser.email')
      email=$(trim "$email") #trim leading and trailing spaces from email string
      email=$(convertToLowerCase "$email")

      local firstName=$(echo $user | jq --raw-output '.idamUser.firstName')
      firstName=$(trim "$firstName") #trim leading and trailing spaces from firstname string

      local lastName=$(echo $user | jq --raw-output '.idamUser.lastName')
      lastName=$(trim "$lastName") #trim leading and trailing spaces from lastName string

      local operation=$(echo $user | jq --raw-output '.extraCsvData.operation')
      operation=$(trim "$operation")
      operation=$(convertToLowerCase "$operation")

      # leading and trailing spaces between roles is taken care in the function call to convert_input_file_to_json
      local rolesFromCSV=$(echo $user | jq --raw-output '.idamUser.roles')

      #raw roles as string
      local strRolesFromCSV=$(echo $user | jq --raw-output '.extraCsvData.roles')
      strRolesFromCSV=$(trim "$strRolesFromCSV")

      # load formatted user JSON ready to send to IDAM
      local idamUserJson=$(echo $user | jq -c --raw-output '.idamUser')

      #inviteStatus from input CSV can take value SUCCESS
      #required so we do not send another registration request if one is already pending
      local inviteStatus=$(echo $user | jq --raw-output '.extraCsvData.status')

      local result=$(echo $user | jq --raw-output '.extraCsvData.result')

      local csvUserId=$(echo $user | jq --raw-output '.idamUser.id')
      local csvSSOId=$(echo $user | jq --raw-output '.idamUser.ssoId')

      log_debug "==============================================="
      log_debug "processing user with email: ${email}"

      if [ "$inviteStatus" != "SUCCESS" ]; then

        # regardless if operation (add/remove) we should always check if the user already exists or not

        #assume 404 user not found as search api returns an empty array when not found
        local rawReturnedValue="HTTP-404"

         #use new api to search user by elasticsearch query
        local rawReturnedValueArray=$(get_user_api_v1 "${email}")

        if [[ ${rawReturnedValueArray} != *"HTTP-"* ]] && [[ ${rawReturnedValueArray} != *"ERROR"* ]]; then
            if [ $(echo $rawReturnedValueArray | jq -e '. | length') != 0 ]; then
                #array not empty, perform logic
                if [ "$csvSSOId" != "null" ]; then
                    #loop through all the returned users to find the correct one matching the ssoId provided

                    for userJson in $(echo "$rawReturnedValueArray" | jq -c -r '.[]'); do
                        local apiSSOId=$(echo $userJson | jq --raw-output '.ssoId')
                        if [ "${apiSSOId}" = "${csvSSOId}" ]; then
                            #correct user object found
                            rawReturnedValue=${userJson}
                            break
                        fi
                    done
                else
                    #elastic search seems to return same user mutliple times
                    #for userJson in $(echo "$rawReturnedValueArray" | jq -c -r '.[]'); do

                    #    local userJsonId=$(echo $userJson | jq --raw-output '.id')
                    #    local rawUserById=$(get_user_by_id "$userJsonId" )

                    #    if [[ ${rawUserById} != *"HTTP-"* ]] && [[ ${rawUserById} != *"ERROR"* ]]; then
                    #        rawReturnedValue="${rawUserById}"
                    #        break
                    #    fi
                    #done

                    #get the first item from the array
                    rawReturnedValue=$(echo $rawReturnedValueArray | jq '.[]' | jq --slurp '.[0]')
                fi
            fi
        fi

        if [ "$csvSSOId" != "null" ]; then
            outputSSOId="${csvSSOId}"
        fi

        if [[ ${rawReturnedValue} != *"HTTP-"* ]] && [[ ${rawReturnedValue} != *"ERROR"* ]]; then
          local userId=$(echo ${rawReturnedValue} | jq --raw-output '.id')
          local userActiveState=$(echo ${rawReturnedValue} | jq --raw-output '.active') # i.e. ACTIVE
          isActive="${userActiveState}"

          #local userRecordType=$(echo $userObject | jq --raw-output '.recordType') # i.e. LIVE

          local firstNameFromApi=$(echo ${rawReturnedValue} | jq --raw-output '.forename')
          local lastNameFromApi=$(echo ${rawReturnedValue} | jq --raw-output '.surname')

          #local rawUserRoles=$(get_user_roles "$userId" )
          #local usersRolesFromApi=$(echo $rawUserRoles | jq --raw-output '.roles')

          local usersRolesFromApi=$(echo $rawReturnedValue | jq --raw-output '.roles')
          lastModified=$(echo $rawReturnedValue | jq --raw-output '.lastModified')

          #log_debug "email: ${email}"
          #log_debug "user_id: ${userId}"
          #log_debug "roles from API call: ${usersRolesFromApi}"
        fi

        log_debug "original roles from CSV: ${rolesFromCSV}"

        if [ $(echo $rolesFromCSV | jq -e '. | length') != 0 ]; then
          rolesFromCSV=$(convertJsonStringArrayToLowerCase "${rolesFromCSV}")
        fi

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

        if [ $(contains "${OPS[@]}" "${operation}") == "n" ]; then

          # FAIL:
          fail_counter=$((fail_counter+1))
          #local reason="Operation '${operation}' is invalid, valid operations are: ${OPS[@]}"
          local reason="Operation '${operation}' is invalid"
          responseMessage="ERROR: $reason"
          inviteStatus="FAILED"
          log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
          echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}${reason}${NORMAL}"

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""

        elif ! $(validateEmailAddress "${email}"); then

          fail_counter=$((fail_counter+1))
          local reason="${InvalidEmailDetected}"
          responseMessage="ERROR: $reason"
          inviteStatus="FAILED"
          log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
          echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""

        elif ([ $(echo ""$rolesFromCSV | jq -e '. | length') == 0 ]) && ([ "$operation" == "add" ] || [ "$operation" == "delete" ]); then

            # FAIL:
            fail_counter=$((fail_counter+1))
            local reason="${NoRolesDefined}"
            responseMessage="ERROR: $reason"
            inviteStatus="FAILED"
            log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
            echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"

            # prepare output (NB: escape generated values for CSV)
            input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
            timestamp=$(date -u +"%FT%H:%M:%SZ")
            output_csv="$input_csv,\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""

        elif ([ $(validateRoleString "${strRolesFromCSV}") -eq 0 ]) && ([ "$operation" == "add" ] || [ "$operation" == "delete" ]); then

            # FAIL:
            fail_counter=$((fail_counter+1))
            local reason="${RolesDefinedContainInvalidCharacters}"
            responseMessage="ERROR: $reason"
            inviteStatus="FAILED"
            log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
            echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"

            # prepare output (NB: escape generated values for CSV)
            input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
            timestamp=$(date -u +"%FT%H:%M:%SZ")
            output_csv="$input_csv,\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""

        elif [[ $rawReturnedValue == *"HTTP-"* ]] && [ "$csvSSOId" != "null" ]; then

            #user with given ssoID not found
            fail_counter=$((fail_counter+1))
            local reason="${userNotFound} with provided ssoID"
            responseMessage="ERROR: $reason"
            inviteStatus="FAILED"
            log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
            echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"

            # prepare output (NB: escape generated values for CSV)
            input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
            timestamp=$(date -u +"%FT%H:%M:%SZ")
            output_csv="$input_csv,\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""

        elif [[ $rawReturnedValue == *"HTTP-"* ]] && [ "$operation" == "find" ]; then

            fail_counter=$((fail_counter+1))
            local reason="${userNotFound}"
            responseMessage="ERROR: $reason"
            inviteStatus="FAILED"
            log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
            echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"

            # prepare output (NB: escape generated values for CSV)
            input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
            timestamp=$(date -u +"%FT%H:%M:%SZ")
            output_csv="$input_csv,\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "find" ]; then
            local strApi_v1_user_roles=""

            for apiRole in $(echo "${usersRolesFromApi}" | jq -r '.[]'); do
                if [ "${strApi_v1_user_roles}" = "" ]; then
                    strApi_v1_user_roles="${apiRole}"
                else
                    strApi_v1_user_roles="$strApi_v1_user_roles|${apiRole}"
                fi
            done

            #echo "roles $usersRolesFromApi"

            # SUCCESS:
            success_counter=$((success_counter+1))
            local reason="User details successfully retrieved"
            #for success there is no need to output into the responseMessage column
            responseMessage=""
            inviteStatus="SUCCESS"
            log_debug "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
            echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}${reason}${NORMAL}"

            # prepare output (NB: escape generated values for CSV)
            input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email] | @csv')
            timestamp=$(date -u +"%FT%H:%M:%SZ")
            output_csv="$input_csv,\"$firstNameFromApi\",\"$lastNameFromApi\",\"$strApi_v1_user_roles\",\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""

        elif [ "$operation" == "add" ] && [[ "$ENABLE_USERID_REGISTRATIONS" = true ]]; then
            # add id logic here
            if [ "$csvUserId" == "null" ]; then
              # SKIP:
              skipped_counter=$((skipped_counter+1))
              inviteStatus="SKIPPED"
              local reason="Field: 'userId' required, but not provided"
              responseMessage="WARN: $reason"

              log_warn "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
              echo "${NORMAL}${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${reason}${NORMAL}"
            elif [ "$firstName" == "null" ] && [ "$lastName" == "null" ]; then
                # FAIL:
                fail_counter=$((fail_counter+1))
                local reason="${BothFirstAndLastnameCannotBeEmpty}"
                responseMessage="ERROR: $reason"
                inviteStatus="FAILED"
                log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
                echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"
            else
                if [ "$csvUserId" == "use-existing-user-id" ]; then
                    log_debug "${email}, existing user with id: ${userId}"
                    #replace json id with existing users id
                    idamUserJson=$(echo $idamUserJson | jq --arg existingUserID "${userId}" '.id = ($existingUserID)')
                fi
                log_debug "idamUserJson: ${idamUserJson}"

                # make call to IDAM
                submit_response=$(submit_user_registation "$idamUserJson")

                # seperate submit_user_registation reponse
                IFS=$'\n'
                local response_array=($submit_response)
                local inviteStatus=${response_array[0]}
                local responseMessage=${response_array[1]}

                if [ $inviteStatus == "SUCCESS" ]; then
                    # SUCCESS:
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
                    # FAIL:
                    fail_counter=$((fail_counter+1))
                    local reason="failed registering user"
                    responseMessage="ERROR: $responseMessage"
                    inviteStatus="FAILED"
                    echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${responseMessage}${NORMAL}"
                    log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason} - ${responseMessage}"
                fi
            fi

            # prepare output (NB: escape generated values for CSV)
            input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
            timestamp=$(date -u +"%FT%H:%M:%SZ")
            output_csv="$input_csv,\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""

        elif [[ $rawReturnedValue == *"HTTP-"* ]] && [ "$operation" == "add" ]; then

          log_debug "email: ${email} - User does not exist, doing add new user logic"

          if [ "$firstName" == "null" ] && [ "$lastName" == "null" ]; then
            # FAIL:
            fail_counter=$((fail_counter+1))
            local reason="${BothFirstAndLastnameCannotBeEmpty}"
            responseMessage="ERROR: $reason"
            inviteStatus="FAILED"
            log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
            echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"
          else
            local bRolesDiscarded=false
            local discardedRolesMessage=""

            if [ $(checkAllowedRole "${rolesFromCSV}" "${MANUAL_ROLES}") -eq 1 ]; then
                local discardedRoles=$(returnNotAllowedRoles "${rolesFromCSV}" "${MANUAL_ROLES}")
                rolesFromCSV=$(stripNotAllowedRoles "${rolesFromCSV}" "${MANUAL_ROLES}")
                discardedRolesMessage="WARN: the following role(s) can only be added by eJust 3rd Line support via Snow: "
                discardedRolesMessage="$discardedRolesMessage ${discardedRoles[*]}"
                log_warn "file: ${filename} , action: ${operation} , email: ${email} , status: ${discardedRolesMessage}"
                bRolesDiscarded=true
            fi

            #rolesFromCSV=$(addPreDefinedRolesToCSVRoles "${rolesFromCSV}")

            if [ $(checkShouldAddDefaultRoles "${rolesFromCSV}") -eq 1 ]; then
                log_debug "Adding default roles"
                rolesFromCSV=$(addRolesToCSVRoles "${rolesFromCSV}" "${ADD_ROLES_BY_DEFAULT}")
            else
                log_debug "Skipping addition of default roles"
            fi

            log_debug "Final roles to apply: ${rolesFromCSV}"

            if [[ "$firstName" == "null" ]]; then
                log_debug "firstName is empty setting to ' '"
                idamUserJson=$(echo $idamUserJson | jq '.firstName = " "')
            elif [[ "$lastName" == "null" ]]; then
                log_debug "lastName is empty setting to ' '"
                idamUserJson=$(echo $idamUserJson | jq '.lastName = " "')
            fi

            if [ "${rolesFromCSV}" = "[]" ]; then
                # FAIL:
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
                #Need to update the roles in idamUserJson
                idamUserJson=$(echo $idamUserJson | jq --argjson rolesFromCSV "${rolesFromCSV}" '.roles = $rolesFromCSV')

                log_debug "idamUserJson: ${idamUserJson}"

                # make call to IDAM
                submit_response=$(submit_user_registation "$idamUserJson")

                # seperate submit_user_registation reponse
                IFS=$'\n'
                local response_array=($submit_response)
                local inviteStatus=${response_array[0]}
                local responseMessage=${response_array[1]}

                if [ $inviteStatus == "SUCCESS" ]; then
                    # SUCCESS:
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
                    # FAIL:
                    fail_counter=$((fail_counter+1))
                    local reason="failed registering user"
                    responseMessage="ERROR: $responseMessage"
                    inviteStatus="FAILED"
                    echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${responseMessage}${NORMAL}"
                    log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason} - ${responseMessage}"
                fi
            fi
          fi

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "add" ]; then

          log_debug "email: ${email} - User exists, doing role addition logic"

          log_debug "Current assigned roles (based on API): ${usersRolesFromApi}"

          local bRolesDiscarded=false
          local discardedRolesMessage=""

          if [ $(checkAllowedRole "${rolesFromCSV}" "${MANUAL_ROLES}") -eq 1 ]; then
            local discardedRoles=$(returnNotAllowedRoles "${rolesFromCSV}" "${MANUAL_ROLES}")
            rolesFromCSV=$(stripNotAllowedRoles "${rolesFromCSV}" "${MANUAL_ROLES}")
            discardedRolesMessage="WARN: the following role(s) can only be added by eJust 3rd Line support via Snow: "
            discardedRolesMessage="$discardedRolesMessage ${discardedRoles[*]}"
            log_warn "file: ${filename} , action: ${operation} , email: ${email} , status: ${discardedRolesMessage}"
            bRolesDiscarded=true
          fi

          combinedCsvApiRoles=$(echo $rolesFromCSV $usersRolesFromApi | jq '.[]' | jq -s)

          #rolesFromCSV=$(addPreDefinedRolesToCSVRoles "${rolesFromCSV}")

          if [ $(checkShouldAddDefaultRoles "${rolesFromCSV}") -eq 1 ]; then
            log_debug "Adding default roles"
            rolesFromCSV=$(addRolesToCSVRoles "${rolesFromCSV}" "${ADD_ROLES_BY_DEFAULT}")
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
            local responseMessage=${response_array[1]}

            if [ $inviteStatus == "SUCCESS" ]; then
              # SUCCESS:
              success_counter=$((success_counter+1))
              lastModified=$(date -u +"%FT%H:%M:%SZ")
              inviteStatus="SUCCESS"
              local reason="role(s) successfully assigned"
              echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}$reason${NORMAL}"
              log_debug "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
              responseMessage=""
              #Set user activate state to true if false
              if [ $userActiveState == "false" ]; then
                log_debug "email: ${email} - User activate state=false, activating user"
                #user activate state is false, need to call patch user api to set to true first
                #note, update_user is a PATCH call, but we cannot modify any roles using this endpoint
                body='{"active":true}'
                submit_response=$(update_user "${userId}" "${body}")

                #if [[ "$submit_response" == *"$email"* ]]; then
                if [[ $submit_response =~ .*email.* ]]; then
                  log_info "file: ${filename} , email: ${email} - SUCCESS, user active state set to true"
                  isActive="TRUE"
                  responseMessage="INFO: user has been activated"
                else
                  log_error "file: ${filename} , email: ${email} - FAILED, user active state could not be set"
                  responseMessage="ERROR: user active state could not be set to true"
                fi
              fi

              if [[ "$bRolesDiscarded" = true ]]; then
                  responseMessage="$responseMessage $discardedRolesMessage"
              fi
            else
              # FAIL:
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
            # SKIP:
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

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "updatename" ]; then

          log_debug "email: ${email} - User exists, doing update firstname lastname logic"

          if [ $userActiveState == "true" ]; then
            if [ "${firstName}" != "${firstNameFromApi}" ] || [ "$lastName" != "${lastNameFromApi}" ]; then
              if [ "$firstName" == "null" ] && [ "$lastName" == "null" ]; then
                # FAIL:
                fail_counter=$((fail_counter+1))
                local reason="${BothFirstAndLastnameCannotBeEmpty}"
                responseMessage="ERROR: $reason"
                inviteStatus="FAILED"
                log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
                echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"
              else
                log_debug "email: ${email} - doing firstname/lastname update"

                if [ "$firstName" == "null" ] && [ "$lastName" != "null" ]; then
                  body='{"surname": "'${lastName}'"}'
                elif [ "$lastName" == "null" ] && [ "$firstName" != "null" ]; then
                  body='{"forename": "'${firstName}'"}'
                else
                  body='{"forename": "'${firstName}'","surname": "'${lastName}'"}'
                fi

                submit_response=$(update_user "${userId}" "${body}")

                # seperate submit_response
                IFS=$'\n'
                local response_array=($submit_response)
                local inviteStatus=${response_array[0]}
                local responseMessage=${response_array[1]}

                #if [[ "${submit_response}" == *"${email}"* ]]; then
                if [[ $submit_response =~ .*email.* ]]; then
                  # SUCCESS:
                  success_counter=$((success_counter+1))
                  lastModified=$(date -u +"%FT%H:%M:%SZ")
                  inviteStatus="SUCCESS"
                  local reason="user firstname/lastname successfully updated"
                  log_debug "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
                  echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}${reason}${NORMAL}"
                else
                  # FAIL:
                  fail_counter=$((fail_counter+1))
                  inviteStatus="FAILED"
                  local reason="failed updating user firstname/lastname"
                  log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
                  echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${responseMessage}${NORMAL}"
                fi
              fi
            else
              # SKIP:
              skipped_counter=$((skipped_counter+1))
              inviteStatus="SKIPPED"
              local reason="no changes in firstname/lastname detected, nothing to update"
              responseMessage="WARN: $reason"
              log_warn "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
              echo "${NORMAL}${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${reason}${NORMAL}"
            fi
          else
            # SKIP:
            skipped_counter=$((skipped_counter+1))
            inviteStatus="SKIPPED"
            local reason="${UserExistsNotActive}"
            responseMessage="WARN: $reason"
            log_warn "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
            echo "${NORMAL}${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${inviteStatus} - ${reason}${NORMAL}"
          fi

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""

        elif [[ $rawReturnedValue == *"HTTP-"* ]] && [ "$operation" == "delete" ] || [ "$operation" == "updatename" ]; then

          skipped_counter=$((skipped_counter+1))
          inviteStatus="SKIPPED"
          local reason="User does not exist, cannot process $operation operation"
          responseMessage="WARN: $reason"
          log_warn "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
          echo "${NORMAL}${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${reason}${NORMAL}"

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "delete" ] && [ $(checkAllowedRole "${rolesFromCSV}" "${MANUAL_ROLES}") -eq 1 ]; then

          # FAIL:
          fail_counter=$((fail_counter+1))
          local reason="One or more roles defined cannot be assigned using this script"
          responseMessage="ERROR: $reason"
          inviteStatus="FAILED"
          log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
          echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "delete" ]; then

          log_debug "email: ${email} - User exists, doing deletion logic"

          local USE_PUT=0

          local default_caseworker_role_provided=false
          local default_caseworker_role_already_assigned=false

          #declare empty bash array of roles to remove
          local rolesToRemoveArray=()

          #declare empty bash array to store api fetched roles
          local rolesFromApiArray=()

          log_debug "Current assigned roles (based on API): ${usersRolesFromApi}"

          if [ $(checkJsonContainsStringRole "${rolesFromCSV}" "${ALL_ROLES}") -eq 1 ]; then
            log_debug "Operation: ${operation}, contains role:  ${ALL_ROLES}, PUT API call will be used to remove all roles and de-activate the user"
            USE_PUT=1
          elif [ $(echo $usersRolesFromApi | jq -e '. | length') == 0 ]; then
            log_debug "Operation: ${operation}, User currently has NO roles assigned, PUT API call will be used to de-activate the user"
            USE_PUT=1
          else
            #populate array with fetched api roles
            for apiRole in $(echo "${usersRolesFromApi}" | jq -r '.[]'); do
                if [ "$apiRole" == "${ADD_ROLES_BY_DEFAULT}" ]; then
                    default_caseworker_role_already_assigned=true
                fi
                rolesFromApiArray+=("${apiRole}")
            done

            #add the expanded roles if required (i.e. ia_roles etc.)
            rolesFromCSV=$(addPreDefinedRolesToCSVRoles "${rolesFromCSV}")

            log_debug "Computed/expanded CSV roles supplied for deletion: ${rolesFromCSV}"

            for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
                if [ "$csvRole" == "${ADD_ROLES_BY_DEFAULT}" ]; then
                    default_caseworker_role_provided=true
                fi
                if [ $(checkArrayContainsStringRole "${IGNORED_ROLES_FROM_USER_DELETE_REQUEST}" "${csvRole}") -eq 1 ]; then
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

            #Check if any more caseworker-* roles remain for the user
            #if not then safe to remove caseworker
            local otherServiceRole=false
            for role in "${rolesFromApiArray[@]}"
            do
                if [[ "${role}" == "${ADD_ROLES_BY_DEFAULT}-"* ]]; then
                    otherServiceRole=true
                    break
                fi
            done

            local rolesToDeleteByDefaultArray=( $(splitStringToArray "|" "${DELETE_ROLES_BY_DEFAULT}") )

            if [[ "$otherServiceRole" = false ]]; then
                for apiRole in "${rolesFromApiArray[@]}"; do
                    if [ $(checkArrayContainsStringRole "${DELETE_ROLES_BY_DEFAULT}" "${apiRole}") -eq 1 ]; then
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

            if [ $rolesFromApiArray_count == 0 ]; then
                USE_PUT=1
            fi
          fi

          if [ $userActiveState == "true" ]; then
            if [ $USE_PUT -eq 1 ]; then
              log_debug "After processing required role deletions, no roles would remain, using PUT to remove ALL roles and then disable the user"
              submit_response=$(put_user_roles "$userId" "[]")

              # seperate submit_response reponse
              IFS=$'\n'
              local response_array=($submit_response)
              local inviteStatus=${response_array[0]}
              local responseMessage=${response_array[1]}

              if [ $inviteStatus == "SUCCESS" ]; then
                # SUCCESS:

                local warnSetActiveStateMessage=""

                #Set user activate state to false
                if [ $userActiveState == "true" ]; then
                    log_debug "email: ${email} - User activate state=true, de-activating user"
                    body='{"active":false}'
                    submit_response=$(update_user "${userId}" "${body}")

                    # seperate submit_response reponse
                    IFS=$'\n'
                    local response_array=($submit_response)
                    local inviteStatus=${response_array[0]}
                    local responseMessage=${response_array[1]}

                    #if [[ "$submit_response" == *"$email"* ]]; then
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

                success_counter=$((success_counter+1))
                lastModified=$(date -u +"%FT%H:%M:%SZ")
                inviteStatus="SUCCESS"
                local reason="All roles were successfully removed from the user"

                if [ $userActiveState == "true" ]; then
                    echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}$reason${NORMAL}: ${YELLOW}${warnSetActiveStateMessage}"
                else
                    echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}$reason${NORMAL}"
                fi

                log_debug "action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
                responseMessage="${reason} ${responseMessage} ${warnSetActiveStateMessage}"
              else
                # FAIL:
                fail_counter=$((fail_counter+1))
                inviteStatus="FAILED"
                local reason="Failed removing all roles"
                echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason - ${responseMessage}${NORMAL}"
                log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason} - ${responseMessage}"
              fi
            else
              local addedCounter=0
              local failedToAddCounter=0

              local rolesToRemoveArray_count=${#rolesToRemoveArray[@]}

              local rolesDeleted=()
              local rolesNotDeleted=()

              #for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
              for csvRole in "${rolesToRemoveArray[@]}"; do
                submit_response=$(delete_user_role "$userId" "$csvRole")
                # seperate submit_response reponse
                IFS=$'\n'
                local response_array=($submit_response)
                local inviteStatus=${response_array[0]}
                local responseMessage=${response_array[1]}

                if [ $inviteStatus == "SUCCESS" ]; then
                  addedCounter=$((addedCounter+1))
                  local reason="role $csvRole successfully removed"
                  log_info "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
                  rolesDeleted+=("${csvRole}")
                else
                  # FAIL:
                  failedToAddCounter=$((failedToAddCounter+1))
                  local reason="failed removing role $csvRole"
                  log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason} - ${responseMessage}"
                  rolesNotDeleted+=("${csvRole}")
                fi
              done

              if [ $rolesToRemoveArray_count == 0 ]; then
                # SKIPPED:
                skipped_counter=$((skipped_counter+1))
                inviteStatus="SKIPPED"
                local reason="None of the roles defined are currently assigned to the user"
                responseMessage="WARN: $reason"
                log_warn "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
                echo "${NORMAL}${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${reason}${NORMAL}"
              elif [ "$failedToAddCounter" -gt 0 ] && [ "$addedCounter" -gt 0 ]; then
                # PARTIALLY-FAILED:
                fail_counter=$((fail_counter+1))
                lastModified=$(date -u +"%FT%H:%M:%SZ")
                inviteStatus="PARTIALLY-FAILED"
                local reason="Some roles could not be unassigned, please check logs for further information"
                responseMessage="ERROR: $reason"
                 "${alpha[@]}"
                responseMessage="INFO: Roles successfully removed: "${rolesDeleted[@]}" ERROR: Roles failed removal: "${rolesNotDeleted[*]}""
                echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"
                log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
              elif [ "$failedToAddCounter" -eq 0 ] && [ "$addedCounter" -gt 0 ]; then
                # SUCCESS:
                success_counter=$((success_counter+1))
                lastModified=$(date -u +"%FT%H:%M:%SZ")
                inviteStatus="SUCCESS"
                local reason="Specified roles were successfully removed from the user"
                responseMessage="INFO: Roles successfully removed: "${rolesDeleted[*]}""
                echo "${NORMAL}${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: Status == ${GREEN}$reason${NORMAL}"
                log_info "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
              else
                # FAIL:
                fail_counter=$((fail_counter+1))
                inviteStatus="FAILED"
                local reason="Roles could not be unassigned, please check logs for further information"
                responseMessage="ERROR: $reason"
                echo "${NORMAL}${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: Status == ${RED}$reason${NORMAL}"
                log_error "file: ${filename} , action: ${operation} , email: ${email} , status: ${inviteStatus} - ${reason}"
              fi
            fi
          else
            # SKIP:
            skipped_counter=$((skipped_counter+1))
            inviteStatus="SKIPPED"
            local reason="${UserExistsNotActive}"
            responseMessage="WARN: $reason"
            log_warn "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"
            echo "${NORMAL}${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${inviteStatus} - ${reason}${NORMAL}"
          fi

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""
        fi

      else

        # SKIP:
        skipped_counter=$((skipped_counter+1))
        local reason="Request already processed previously"
        responseMessage="WARN: $reason"
        echo "${NORMAL}${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${inviteStatus} - ${reason}${NORMAL}"
        log_warn "file: ${filename} , action: ${operation}, email: ${email} , status: ${inviteStatus} - ${reason}"

        # prepare output
        input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
        timestamp=$(date -u +"%FT%H:%M:%SZ")
        output_csv="$input_csv,\"$isActive\",\"$lastModified\",\"$outputSSOId\",\"$inviteStatus\",\"${responseMessage//\"/\"\"}\""

      fi

      local isResultColumnPresent=0
      if [[ "$result" != "null" ]]; then
          isResultColumnPresent=1
          if [ "${result}" == "${inviteStatus}" ]; then
            test_pass_counter=$((test_pass_counter+1))
          else
            test_fail_counter=$((test_fail_counter+1))
            log_debug "test failed at record number: $((total_counter+1))"
          fi
      fi

      # record log of action in output file (NB: escape values for CSV)
      echo "$output_csv" >> "$filepath_output_newpath"
    done

    log_debug "****** End - processing input file ${filepath_input_original}"

    echo "${NORMAL}Process is complete: ${GREEN}success: ${success_counter}${NORMAL}, ${YELLOW}skipped: ${skipped_counter}${NORMAL}, ${RED}fail: ${fail_counter}${NORMAL}, total: ${total_counter}"

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
  )

else
  echo $json

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
