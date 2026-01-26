#!/bin/sh

IMPORTER_USERNAME=${1:-ccd.docker.default@hmcts.net}
IMPORTER_PASSWORD=${2:-Pa55word11}
IDAM_URI=${IDAM_OVERRIDE_URL:-http://localhost:5000}
REDIRECT_URI="http://localhost:3451/oauth2redirect"
CLIENT_ID=${3:-ccd_gateway}
CLIENT_SECRET=${4:-ccd_gateway_secret}
CURL_OPTS="$CURL_OPTS -S --silent"
SCOPE=${5:-openid profile roles}

if [ -z "${IDAM_FULL_ENABLED:-}" ]; then
  echo "IDAM_FULL_ENABLED is not set. Using IDAN-SIM as default : ${IDAM_API_BASE_URL:-http://localhost:5000}"
  IDAM_URI=${IDAM_API_BASE_URL:-http://localhost:5000}
  curl ${CURL_OPTS} -XPOST "${IDAM_URI}/o/token" \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "client_id=${CLIENT_ID}" \
    --data-urlencode "client_secret=${CLIENT_SECRET}" \
    --data-urlencode "grant_type=password" \
    --data-urlencode "redirect_uri=${REDIRECT_URI}" \
    --data-urlencode "username=${USERNAME}" \
    --data-urlencode "password=${PASSWORD}" \
    --data-urlencode "scope=${SCOPE}" | jq -r .access_token
else 
  echo "IDAM_OVERRIDE_URL is set. Using IDAM url : ${IDAM_OVERRIDE_URL:-http://localhost:5000}"
  code=$(curl ${CURL_OPTS} -u "${IMPORTER_USERNAME}:${IMPORTER_PASSWORD}" -XPOST "${IDAM_URI}/oauth2/authorize?redirect_uri=${REDIRECT_URI}&response_type=code&client_id=${CLIENT_ID}" -d "" | jq -r .code)
  curl ${CURL_OPTS} -H "Content-Type: application/x-www-form-urlencoded" -u "${CLIENT_ID}:${CLIENT_SECRET}" -XPOST "${IDAM_URI}/oauth2/token?code=${code}&redirect_uri=${REDIRECT_URI}&grant_type=authorization_code" -d "" | jq -r .access_token
fi
