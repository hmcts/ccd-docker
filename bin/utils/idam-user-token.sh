#!/bin/sh

USERNAME=${1:-ccd.docker.default@hmcts.net}
PASSWORD=${2:-Pa55word11}
IDAM_URI=${IDAM_URI_OVERRIDE:-http://localhost:5000}
REDIRECT_URI="http://localhost:3451/oauth2redirect"
CLIENT_ID=${3:-ccd_gateway}
CLIENT_SECRET=${4:-ccd_gateway_secret}
CURL_OPTS="$CURL_OPTS -S --silent"
SCOPE=${5:-openid profile roles}

curl ${CURL_OPTS} -XPOST "${IDAM_URI}/o/token" \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "client_id=${CLIENT_ID}" \
    --data-urlencode "client_secret=${CLIENT_SECRET}" \
    --data-urlencode "grant_type=password" \
    --data-urlencode "redirect_uri=${REDIRECT_URI}" \
    --data-urlencode "username=${USERNAME}" \
    --data-urlencode "password=${PASSWORD}" \
    --data-urlencode "scope=${SCOPE}" | jq -r .access_token
