#!/usr/bin/env bash

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
    idam_token=$(
         curl --silent --fail --show-error -X POST "${IDAM_URL}/o/token" \
            -H "accept: application/json" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "client_id=${CLIENT_ID}&client_secret=${IDAM_CLIENT_SECRET}&grant_type=password&username=${ADMIN_USER}&password=${ADMIN_USER_PWD}&redirect_uri=${REDIRECT_URI}&scope=openid roles create-user" \
            | jq -r .access_token
         )
    echo "$idam_token"
}

# read input arguments
read -p "Please enter csv file path: " CSV_FILE_PATH
read -p "Please enter ccd idam-admin username: " ADMIN_USER
read -s -p "Please enter ccd idam-admin password: " ADMIN_USER_PWD
read -s -p $'\nPlease enter idam client secret for create-bulk-users:' IDAM_CLIENT_SECRET
read -p $'\nPlease enter environment default [prod]: ' ENV

ENV=${ENV:-prod}

if [ -z "${CSV_FILE_PATH}" ] || [ -z "${ADMIN_USER}" ] || [ -z "${ADMIN_USER_PWD}" ] || [ -z "${IDAM_CLIENT_SECRET}" ]
then
  echo "Please provide all required inputs to the script. Try running again ./bulk-user-creation.sh"
  exit 1
fi

REDIRECT_URI="https://create-bulk-user-test/oauth2redirect"
CLIENT_ID="create-bulk-users"
IDAM_URL=$(get_idam_url)
IDAM_ACCESS_TOKEN=$(get_idam_token)

if [ -z "$IDAM_ACCESS_TOKEN" ]
then
    echo "Problem getting idam token for admin user: $ADMIN_USER"
    exit 1
fi

# TODO: read csv and call curl in a loop for each record
curl -X POST "${IDAM_URL}/user/registration" -H "accept: application/json" -H "Content-Type: application/json" \
    -H "authorization:Bearer ${IDAM_ACCESS_TOKEN}" \
    -d '{"email":"Joan45.williams@justice.gov.uk","firstName":"Joanna", "lastName": "Williams", "roles":[ "ccd-import"] }'

