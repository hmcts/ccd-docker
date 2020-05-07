#!/usr/bin/env bash

CSV_FILE_PATH="$1"
ADMIN_USER="$2"
ADMIN_USER_PWD="$3"
IDAM_CLIENT_SECRET="$4"
ENV=${5:-prod}

REDIRECT_URI="https://create-bulk-user-test/oauth2redirect"
CLIENT_ID="create-bulk-users"

function usage() {
  echo "usage: ./bulk-user-creation.sh <user-csv-file-path> <ccd-admin-user> <ccd-admin-user-pwd> <idam-client-secret> <optional-env>"
  echo "example: ./bulk-user-creation.sh /Users/xyz/bulk-users.csv ccd-test-admin@mail.com test-password bulk-users-client-secret aat"
}

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

if [ -z "${CSV_FILE_PATH}" ] || [ -z "${ADMIN_USER}" ] || [ -z "${ADMIN_USER_PWD}" ] || [ -z "${IDAM_CLIENT_SECRET}" ]
then
  usage
  exit 1
fi

IDAM_URL=$(get_idam_url)
idam_access_token=$(get_idam_token)

# TODO: read csv and call curl in a loop for each record

curl -X POST "${IDAM_URL}/user/registration" -H "accept: application/json" -H "Content-Type: application/json" \
    -H "authorization:Bearer ${idam_access_token}" \
    -d '{"email":"Joan45.williams@justice.gov.uk","firstName":"Joanna", "lastName": "Williams", "roles":[ "ccd-import"] }'

