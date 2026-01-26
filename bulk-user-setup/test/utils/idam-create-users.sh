#!/usr/bin/env bash

######################
## FUNCTIONS
######################

get_user_roles() {
  docker run -e PGPASSWORD='openidm' --rm --network ccd-network postgres:11-alpine psql --host shared-db --username openidm --tuples-only --command "SELECT data.roles FROM managedObjects mo, LATERAL (SELECT regexp_replace(string_agg((element::json -> '_ref')::text, ','), '( *\\w*\\/)|(\")', '', 'g') AS roles FROM json_array_elements_text(mo.fullobject->'effectiveRoles') as data(element)) data WHERE mo.fullobject ->> 'userName'='${1}';" openidm
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

function check_exit_code_for_error() {
  local PREVIOUS_EXIT_CODE=$1;
  local PREVIOUS_RESPONSE=$2;

  if ! [ $PREVIOUS_EXIT_CODE -eq 0 ]; then
    # error so echo response and abort
    echo $PREVIOUS_RESPONSE
    exit $PREVIOUS_EXIT_CODE
  fi
}

create_user_request() {
  response=$(
    curl --insecure --show-error --silent --output /dev/null --write-out "%{http_code}" -X POST \
      "${IDAM_OVERRIDE_URL:-http://localhost:5000}"/testing-support/accounts \
      -H "Content-Type: application/json" \
      -d '{
          "email":"'"${email}"'",
          "forename":"'"${firstName}"'",
          "surname":"'"${surname}"'",
          "password":"Pa55word11",
          "levelOfAccess":1,
          "roles": [
            '"${rolesJson}"'
          ]
          }
        '
  )

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

######################
## MAIN
######################
current_dir=$(pwd)
source ${current_dir}/./bulk-user-setup.config 2> /dev/null

set -eu

if [ "${ENVIRONMENT:-local}" != "local" ]; then
  exit 0;
fi

IDAM_URL=${IDAM_OVERRIDE_URL:-http://localhost:5000}
IDAM_ACCESS_TOKEN=$(get_idam_token)
check_exit_code_for_error $? "$IDAM_ACCESS_TOKEN"

if [ -z "$IDAM_ACCESS_TOKEN" ]
then
    echo "${RED}ERROR: Problem getting idam token for admin user:${NORMAL} $ADMIN_USER"
    exit 1
fi

email=${1}
rolesStr=${2}
surname=${3:-"Tester"}
firstName=${4:-${email}}
active=${5:-"true"}

IFS=',' read -ra roles <<<"${rolesStr}"

getUserResponse=$(get_user "$email")

if [[ ${getUserResponse} != *"HTTP-"* ]] && [[ ${getUserResponse} != *"ERROR"* ]]; then
    #user found
    echo "User with email ${email} successfully found"

    userId=$(echo $getUserResponse | jq --raw-output '.id')

    #remove the roles attribute from teh existing user as patch does not allow role update
    body=$(echo $getUserResponse | jq 'del(.roles)')

    #update all attributes to match test case
    body=$(echo $body | jq --arg email "${email}" '.email = ($email)')
    body=$(echo $body | jq --arg surname "${surname}" '.surname = ($surname)')
    body=$(echo $body | jq --arg firstName "${firstName}" '.forename = ($firstName)')
    body=$(echo $body | jq --argjson active "${active}" '.active = ($active)' )

    update_user_response=$(update_user "${userId}" "${body}")
    if [[ ${update_user_response} != *"HTTP-"* ]] && [[ ${update_user_response} != *"ERROR"* ]]; then
        echo "User details for ${email} successfully updated"

        #update the roles to match test case using PUT

        isRoleStringEmpty=true

        rolesJson=''
        for role in "${roles[@]}"; do
          if [[ -n ${rolesJson} ]]; then
            isRoleStringEmpty=false
            rolesJson="${rolesJson},"
          fi
          rolesJson=${rolesJson}'{"name":"'${role}'"}'
        done

        if [[ "$isRoleStringEmpty" = true ]]; then
            rolesJson="[]"
        else
            rolesJson="[${rolesJson}]"
        fi

        put_user_roles_response=$(put_user_roles "${userId}" "${rolesJson}")
        if [[ ${put_user_roles_response} != *"HTTP-"* ]] && [[ ${put_user_roles_response} != *"ERROR"* ]]; then
            echo "User roles for ${email} successfully updated"
        else
            echo "Failed updating roles for ${email}, roles ${rolesJson}"
        fi
    else
        echo "Failed updating user ${email}"
    fi
else
    #create user

    rolesJson=''
    for role in "${roles[@]}"; do
      if [[ -n ${rolesJson} ]]; then
        rolesJson="${rolesJson},"
      fi
      rolesJson=${rolesJson}'{"code":"'${role}'"}'
    done

    create_user_request_response=$(create_user_request)

    IFS=$'\n' arr=($create_user_request_response)
    array_length=${#arr[@]}
    http_body=${arr[0]}
    http_status=${arr[${array_length}-1]}

    if [ ${http_status} -ne 201 ]; then
        echo "Failed creating user ${email}"
    else
        echo "Successfully created user ${email}"
        if [ "${active}" == "false" ]; then
            getUserResponse=$(get_user "$email")
            if [[ ${getUserResponse} != *"HTTP-"* ]] && [[ ${getUserResponse} != *"ERROR"* ]]; then
                userId=$(echo $getUserResponse | jq --raw-output '.id')
                echo "Setting active state to false for user ${email}"
                body='{"active":false}'
                submit_response=$(update_user "${userId}" "${body}")
            fi
        fi
    fi
fi
