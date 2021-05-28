#!/usr/bin/env bash

# console colours / fonts
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

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
      --data-urlencode "redirect_uri=${REDIRECT_URI}" \
      --data-urlencode "scope=openid roles create-user manage-user"
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
    curl -w $"\n%{http_code}" --silent -X POST "${IDAM_URL}/user/registration" -H "accept: application/json" -H "Content-Type: application/json" \
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

function update_user_roles() {
  local ROLES=$1
  local USER=$2

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

function get_user() {
  local EMAIL=$1

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

  local dirname=$(dirname "${original_filename}")
  local basename=$(basename "${original_filename}")
  local filename="${basename%.*}"
  local extension="${basename##*.}"

  # add default CSV extension if none was found
  if [ "$extension" = "" ] || [ "$filename" = "$basename" ]; then
    extension="csv"
  fi

  echo "${dirname}/${filename}.${insert}.${extension}"
}

function convert_input_file_to_json() {
  local file=$1

  verify_csv_tools_are_available

  verify_file_exists "$file"

  # read from CSV by using CSVJSON
  local raw_csv_as_json=$(csvjson --datetime-format "." "$file")

  # verify JSON format  (ie. check mandatory fields are present)
  verify_json_format_includes_field "${raw_csv_as_json}" "email"
  verify_json_format_includes_field "${raw_csv_as_json}" "firstName"
  verify_json_format_includes_field "${raw_csv_as_json}" "lastName"
  verify_json_format_includes_field "${raw_csv_as_json}" "roles"
  verify_json_format_includes_field "${raw_csv_as_json}" "operation"

  # then reformat JSON using JQ
  local input_as_json=$(echo $raw_csv_as_json \
    | jq -r -c 'map({
        "idamUser": {
          "email": .email,
          "firstName": .firstName,
          "lastName": .lastName,
          "roles": (try(.roles | split("|")) // null),
          "rolesToAdd": (try(.rolesToAdd | split("|")) // null),
          "rolesToRemove": (try(.rolesToRemove | split("|")) // null)
        },
        "extraCsvData": {
          "operation": .operation,
          "roles": .roles,
          "inviteStatus": .inviteStatus,
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

  # convert input file to json
  json=$(convert_input_file_to_json "${filepath_input_original}")
  check_exit_code_for_error $? "$json"

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
  echo "operation,email,firstName,lastName,roles,inviteStatus,idamResponse,idamUserJson,timestamp" >> "$filepath_output_newpath"

  # strip JSON into individual items then process in a while loop
  echo $json | jq -r -c '.[]' \
      |  \
  ( success_counter=0;skipped_counter=0;fail_counter=0;total_counter=0;
    while IFS= read -r user; do
      total_counter=$((total_counter+1))

      # extract CSV fields from json to use in output
      local email=$(echo $user | jq --raw-output '.idamUser.email')
      local inviteStatus=$(echo $user | jq --raw-output '.extraCsvData.inviteStatus')
      local operation=$(echo $user | jq --raw-output '.extraCsvData.operation')
      local rolesToAdd=$(echo $user | jq --raw-output '.idamUser.rolesToAdd')
      local rolesToRemove=$(echo $user | jq --raw-output '.idamUser.rolesToRemove')

      if [ "$inviteStatus" != "SUCCESS" ]; then
        
        # load formatted user JSON ready to send to IDAM 
        idamUserJson=$(echo $user | jq -c --raw-output '.idamUser')
        if [ "$operation" == "add" ]; then
          # make call to IDAM to add user
          submit_response=$(submit_user_registation "$idamUserJson")
        elif [ "$operation" == "update" ]; then
          # get user id and roles from IDAM
          local rawReturnedValue=$(get_user "$email")
          submit_response=$rawReturnedValue

          # Prevent further API calls if User ID cannot be returned
          if [[ $rawReturnedValue != *"HTTP-"* ]]; then 
            local userId=$(echo $rawReturnedValue | jq --raw-output '.id')
            local rawUser=$(get_user_roles "$userId" )
            local currentRoles=$(echo $rawUser | jq --raw-output '.roles')

            # Logic test to confirm current roles are returned
            # to prevent data loss
            if [ "${currentRoles}" != "[]" ]; then
              # combine current roles and roles to add
              if [ "${rolesToAdd}" != "null" ]; then
                  combinedRoles=$(echo $currentRoles $rolesToAdd | jq '.[]' | jq -s)
              fi

              # functionality flakey, removing for now
              # remove roles to remove from the combined role list
              # if [ "${rolesToRemove}" != "null" ]; then
              #   for role in ${rolesToRemove[@]}; do
              #     combinedRoles=( "${combinedRoles[@]/$role}" )
              #   done
              # fi
              
              # convert roles to JSON ready to send to IDAM
              combinedRolesJson=$(echo $combinedRoles | jq 'map( {"name" : . } )')

              # make call to IDAM to update roles for existing user
              submit_response=$(update_user_roles "$combinedRolesJson" "$userId")
            else
              # Update response showing why user was skipped
              submit_response=$(echo skiping $email as no current roles have been returned)
            fi  
          else
            submit_response=$(echo "$rawReturnedValue")
          fi
        fi
        # seperate submit_user_registation reponse
        IFS=$'\n'
        local response_array=($submit_response)
        local inviteStatus=${response_array[0]}
        local idamResponse=${response_array[1]}
        if [ $inviteStatus == "SUCCESS" ]; then
          # SUCCESS:
          success_counter=$((success_counter+1))
          echo "${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: ${idamResponse}"
        else
          # FAIL:
          fail_counter=$((fail_counter+1))
          echo "${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: ${idamResponse}"
        fi

        # prepare output (NB: escape generated values for CSV)
        input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
        timestamp=$(date -u +"%FT%H:%M:%SZ")
        output_csv="$input_csv,\"$inviteStatus\",\"${idamResponse//\"/\"\"}\",\"${idamUserJson//\"/\"\"}\",\"$timestamp\""
      else
        # SKIP:
        skipped_counter=$((skipped_counter+1))
        echo "${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: inviteStatus == ${GREEN}${inviteStatus}${NORMAL}"

        # prepare output
        output_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles, .extraCsvData.inviteStatus, .extraCsvData.idamResponse // "", .extraCsvData.idamUserJson, '.extraCsvData.timestamp'] | @csv')

      fi
      # record log of action in output file (NB: escape values for CSV)
      echo "$output_csv" >> "$filepath_output_newpath"
    done

    echo "Process is complete: ${GREEN}success: ${success_counter}${NORMAL}, ${YELLOW}skipped: ${skipped_counter}${NORMAL}, ${RED}fail: ${fail_counter}${NORMAL}, total: ${total_counter}"
  )

  # copy output file back to original input file location so it can be used for re-run
  cp "$filepath_output_newpath" "$filepath_input_original" 2> /dev/null
  if [ $? -eq 0 ]; then
    echo "Updated input file to reflect invite status: ${BOLD}${filepath_input_original}${NORMAL}"
  else
    echo "${RED}ERROR: unable to update input file:${NORMAL} ${filepath_input_original}"
    exit 1
  fi
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
unset https_proxy;