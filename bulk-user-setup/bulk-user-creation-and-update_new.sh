#!/usr/bin/env bash

# console colours / fonts
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
is_test=1

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

function put_user_roles() {
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

function delete_user_roles() {
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
  verify_json_format_includes_field "${raw_csv_as_json}" "operation"
  verify_json_format_includes_field "${raw_csv_as_json}" "email"
  verify_json_format_includes_field "${raw_csv_as_json}" "firstName"
  verify_json_format_includes_field "${raw_csv_as_json}" "lastName"
  verify_json_format_includes_field "${raw_csv_as_json}" "roles"

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
          "inviteStatus": .inviteStatus,
          "idamResponse": .idamResponse,
          "idamUserJson": .idamUserJson,
          "timestamp": .timestamp
        }
      })' ) # NB: extraCsvData element included in JSON to help preserve csv data when skipping an already complete record (i.e. inviteStatus="success")

  echo "$input_as_json"
}

function tester() {
  if [ $is_test -eq 1 ] 
  then
    echo 'got here!'
    exit 0
  fi
}

function user_exists()
{
   if [ -d "${1}" ]; then
       return $(true)
   else
       return $(false)
   fi
}

function isUserExists() {
  local rawReturnedValue=$(get_user "${1}")
  if [[ $rawReturnedValue != *"HTTP-"* ]];
  then
    true
  else
    false
  fi
}

function process_input_file() {
  local filepath_input_original=$1

  # generate new paths for input and output files
  local datestamp=$(date -u +"%FT%H%M%SZ")
  local filepath_input_newpath=$(generate_csv_path_with_insert "$filepath_input_original" "${datestamp}_INPUT")
  local filepath_output_newpath=$(generate_csv_path_with_insert "$filepath_input_original" "${datestamp}_OUTPUT")

  if [ $is_test -eq 1 ]; then
    echo 'Test outputs of resulting files!'
    echo $filepath_input_original
    echo $filepath_input_newpath
    echo $filepath_output_newpath
    #exit 0

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
    echo "operation,email,firstName,lastName,roles,inviteStatus,idamResponse,idamUserJson,timestamp" >> "$filepath_output_newpath"
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

      local operation=$(echo $user | jq --raw-output '.extraCsvData.operation')

      # leading and trailing spaces between roles is taken care in the function call to convert_input_file_to_json
      local rolesFromCSV=$(echo $user | jq --raw-output '.idamUser.roles')

      # load formatted user JSON ready to send to IDAM
      local idamUserJson=$(echo $user | jq -c --raw-output '.idamUser')

      #inviteStatus from input CSV can take value SUCCESS
      #required so we do not send another registration request if one is already pending
      local inviteStatus=$(echo $user | jq --raw-output '.extraCsvData.status')

      if [ "$inviteStatus" != "SUCCESS" ]; then
        # regardless if operation (add/remove) we should always check if the user already exists or not
        local rawReturnedValue=$(get_user "$email")
        if [[ $rawReturnedValue != *"HTTP-"* ]]; then
          local userId=$(echo $rawReturnedValue | jq --raw-output '.id')
          local currentRoles=$(echo $rawReturnedValue | jq --raw-output '.roles')
          local userActiveState=$(echo $rawReturnedValue | jq --raw-output '.active') # i.e. ACTIVE
          #local userRecordType=$(echo $userObject | jq --raw-output '.recordType') # i.e. LIVE

          local rawUserRoles=$(get_user_roles "$userId" )
          local usersRolesFromApi=$(echo $rawUserRoles | jq --raw-output '.roles')

          #echo "User ID: "$userId
          #echo "Fetched Roles from get_user_roles (API)" $usersRolesFromApi
          #echo "Active State from get_user (API):" "userActiveState"
          #echo "Current Roles from get_user (API): " "$currentRoles"
        fi

        #echo "Roles in CSV (CSV): " "$rolesFromCSV"

        if [[ $rawReturnedValue == *"HTTP-"* ]] && [ "$operation" == "add" ]; then
          echo "User does not exist, sending invite registration"

          # make call to IDAM
          submit_response=$(submit_user_registation "$idamUserJson")

          #echo $submit_response

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

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "add" ]; then
          echo "User exists, doing role addition logic"

          #Set user activate state to true if false
          if [ $userActiveState == "false" ]; then
            #user activate state is false, need to call patch user api to set to true first
            #note, update_user is a PATCH call, but we cannot modify any roles using this endpoint
            body='{"active":true}'
            submit_response=$(update_user "${userId}" "${body}")

            if [[ "$submit_response" == *"$email"* ]]; then
              echo "Successfully set user active state to true"
            else
              echo "Failed setting user active state to true"
            fi
          fi

          combinedCsvApiRoles=$(echo $rolesFromCSV $usersRolesFromApi | jq '.[]' | jq -s)

          rolesFromCSV=$(echo "${rolesFromCSV}" | jq --arg new "caseworker" '. += [$new]')

          #bit flaky, better to use the above jq code
          #rolesFromCSV=$(addRequiredMandatoryRole "caseworker" "${rolesFromCSV}")

          ARRAY=() #declare empty shell array

          #start - logic to add only the unique roles in csv by comparing already assigned roles
          for csvRole in $(echo "${rolesFromCSV}" | jq -r '.[]'); do
            local found=0
            for apiRole in $(echo "${usersRolesFromApi}" | jq -r '.[]'); do
              if [ $csvRole == $apiRole ]; then
                found=1
                echo "User already has role: " $csvRole
              fi
            done
            if [ $found -eq 0 ]; then
              #Convert to lower-case if required
              csvRole=$(convertToLowerCase "${csvRole}")
              echo "Unique (TO BE ADDED) " $csvRole
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

          combinedCsvApiRolesJson=$(echo $combinedCsvApiRoles | jq 'map( {"name" : . } ) | unique')
          #echo "JSON array of Combined CSV and API" $combinedCsvApiRolesJson

          uniqueRolesJson=$(echo ${arr} | jq 'map( {"name" : . } ) | unique')
          #echo "JSON array of unique roles is (CALC): " $uniqueRolesJson

          if [ "${uniqueRolesJson}" != "[]" ]; then
            #Alternatively we can call the patch roles API in a for loop as below:
            #for role in "${arr[@]}"
            #do
            #   submit_response=$(patch_user_roles "$role" "$userId")
            #done

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
              echo "${total_counter}: ${email}: ${GREEN}${inviteStatus}${NORMAL}: ${idamResponse}"
              inviteStatus="PASSED"
            else
              # FAIL:
              fail_counter=$((fail_counter+1))
              echo "${total_counter}: ${email}: ${RED}${inviteStatus}${NORMAL}: ${idamResponse}"
              inviteStatus="FAILED"
            fi
          else
            # SKIP:
            inviteStatus="User exists and all groups already assigned"
            skipped_counter=$((skipped_counter+1))
            echo "${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${inviteStatus}${NORMAL}"
            inviteStatus="SKIPPED"
            idamResponse="User exists and all groups already assigned"
          fi

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$inviteStatus\",\"${idamResponse//\"/\"\"}\",\"${idamUserJson//\"/\"\"}\",\"$timestamp\""
        elif [[ $rawReturnedValue == *"HTTP-"* ]] && [ "$operation" == "delete" ]; then
          inviteStatus="User does not exist, cannot process delete operation"
          skipped_counter=$((skipped_counter+1))
          echo "${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: Status == ${YELLOW}${inviteStatus}${NORMAL}"

          inviteStatus="SKIPPED"
          idamResponse="User does not exist"

          # prepare output (NB: escape generated values for CSV)
          input_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles] | @csv')
          timestamp=$(date -u +"%FT%H:%M:%SZ")
          output_csv="$input_csv,\"$inviteStatus\",\"${idamResponse//\"/\"\"}\",\"${idamUserJson//\"/\"\"}\",\"$timestamp\""

        elif [[ $rawReturnedValue != *"HTTP-"* ]] && [ "$operation" == "delete" ]; then
          echo "User exists, processing deletion login"

          # prepare output
          output_csv=$(echo $user | jq -r '[.extraCsvData.operation, .idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles, .extraCsvData.inviteStatus, .extraCsvData.idamResponse // "", .extraCsvData.idamUserJson, '.extraCsvData.timestamp'] | @csv')

        fi
      else
        # SKIP:
        skipped_counter=$((skipped_counter+1))
        echo "${total_counter}: ${email}: ${YELLOW}SKIPPED${NORMAL}: inviteStatus == ${GREEN}${inviteStatus}${NORMAL}"

        # prepare output
        output_csv=$(echo $user | jq -r '[.idamUser.email, .idamUser.firstName, .idamUser.lastName, .extraCsvData.roles, .extraCsvData.inviteStatus, .extraCsvData.idamResponse // "", .extraCsvData.idamUserJson, '.extraCsvData.timestamp'] | @csv')
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

function convertToLowerCase {
  local strTemp=$1
  strTemp=$(echo "${strTemp}" | tr '[:upper:]' '[:lower:]')
  echo "${strTemp}"
}

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
    #json_without_quotes=$(echo ${rolesFromCSV//\"/""})
    #declare -a roles_array=($(echo $json_without_quotes | tr "\n" " " | tr "[" " " | tr "]" " " | tr "," " "))
    #roles_array+=("$strRole")

    tempString=$(echo $rolesFromCSV | sed -e 's/\[ //g' -e 's/\ ]//g' -e 's/\,//g')
    roles_array=( $tempString )

    roles_array+=("$strRole")

    arr='[]'  # Empty JSON array
    for x in "${roles_array[@]}"; do
      #arr=$(jq -n --arg x "$x" --argjson arr "$arr" '$arr + [$x]')
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

if [ $is_test -eq 1 ]
then
  CSV_FILE_PATH="/Users/dineshpatel/Sandbox/CCD_Projects/ccd-docker/bulk-user-setup/Sample input file.csv"
  ADMIN_USER="idamOwner@hmcts.net"
  ADMIN_USER_PWD="Ref0rmIsFun"
  IDAM_CLIENT_SECRET="anything"
  ENV="local"
else
  # read input arguments
  read -p "Please enter csv file path: " CSV_FILE_PATH
  read -p "Please enter ccd idam-admin username: " ADMIN_USER
  ADMIN_USER_PWD=$(read_password_with_asterisk "Please enter ccd idam-admin password: ")
  IDAM_CLIENT_SECRET=$(read_password_with_asterisk $'\nPlease enter idam oauth2 secret for ccd-bulk-user-register client: ')
  read -p $'\nPlease enter environment default [prod]: ' ENV
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
TIMEFORMAT="The input file was processed in: %3lR"
time process_input_file "${CSV_FILE_PATH}"
unset https_proxy;