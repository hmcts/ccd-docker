#!/usr/bin/env bash

set -eu

dir=$(dirname ${0})

LABEL=${1}
CLIENT_ID=${2}
CLIENT_SECRET=${3}
REDIRECT_URL=${4}
SELF_REGISTRATION=${5:-"false"}
SCOPE=${6:-"openid profile roles"}

apiToken=$(${dir}/idam-authenticate.sh "${IDAM_ADMIN_USER}" "${IDAM_ADMIN_PASSWORD}")

echo -e "\nCreating service with:\nLabel: ${LABEL}\nClient ID: ${CLIENT_ID}\nClient Secret: ${CLIENT_SECRET}\nRedirect URL: ${REDIRECT_URL}\n"

STATUS=$(curl --silent --output /dev/null --write-out '%{http_code}' -X POST -H 'Content-Type: application/json' -H "Authorization: AdminApiAuthToken ${apiToken}" \
  ${IDAM_API_BASE_URL:-http://localhost:5000}/services \
  -d '{
    "allowedRoles": [],
    "description": "'${LABEL}'",
    "label": "'${LABEL}'",
    "oauth2ClientId": "'${CLIENT_ID}'",
    "oauth2ClientSecret": "'${CLIENT_SECRET}'",
    "oauth2RedirectUris": ["'${REDIRECT_URL}'"],
    "oauth2Scope": "'"${SCOPE}"'",
    "selfRegistrationAllowed": "'${SELF_REGISTRATION}'"
}')

if [ $STATUS -eq 201 ]; then
  echo "Service created successfully"
elif [ $STATUS -eq 409 ]; then
  echo "Service already exists!"
else
  echo "ERROR: HTTPCODE = $STATUS"
  exit 1
fi
