#!/usr/bin/env bash

CSV_FILE_PATH="$1"
IDAM_ADMIN_USER="$2"
IDAM_ADMIN_USER_PWD="$3"
IDAM_CLIENT_SECRET="$4"
ENV=${5:-prod}

function usage() {
  echo "usage: ./bulk-user-creation.sh <user-csv-file-path> <idam-admin-user> <idam-admin-user-pwd> <idam-client-secret> <optional-env>"
}

if [ -z "${CSV_FILE_PATH}" ] || [ -z "${IDAM_ADMIN_USER}" ] || [ -z "${IDAM_ADMIN_USER_PWD}" ] || [ -z "${IDAM_CLIENT_SECRET}" ]
then
  usage
  exit 1
fi

IDAM_URL="http://localhost:5000"
REDIRECT_URI="http://localhost:3451/oauth2redirect"
CLIENT_ID="create-bulk-users"

if [ "$ENV" == "prod" ]
then
  IDAM_URL="https://idam-api.platform.hmcts.net"
else if [ "$ENV" == "local" ]
then
  IDAM_URL="http://localhost:5000"
else
  IDAM_URL="https://idam-api.${ENV}.platform.hmcts.net"
fi
fi
idam_token=$(
    curl --silent --fail --show-error -X POST "${IDAM_URL}/o/token" -H "accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=${CLIENT_ID}&client_secret=${IDAM_CLIENT_SECRET}&grant_type=password&username=${IDAM_ADMIN_USER}&password=${IDAM_ADMIN_USER_PWD}&redirect_uri=${REDIRECT_URI}&scope=create-user" \
    | jq -r .access_token
     )

echo "$idam_token"


curl -X POST "${IDAM_URL}/user/registration" -H "accept: application/json" -H "Content-Type: application/json" \
    -H "authorization:Bearer ${idam_token}" \
    -d '{"email":"Joan.williams@justice.gov.uk","firstName":"Joanna", "lastName": "Williams", "roles":[ "caseworker-autotest2"] }'
