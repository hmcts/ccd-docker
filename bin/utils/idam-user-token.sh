#!/bin/sh

IMPORTER_USERNAME=${1:-fr_applicant_sol@sharklasers.com}
IMPORTER_PASSWORD=${2:-Testing1234}
IDAM_URI=${IDAM_STUB_LOCALHOST:-https://idam-api.aat.platform.hmcts.net}
REDIRECT_URI="https://div-pfe-aat.service.core-compute-aat.internal/authenticated"
CLIENT_ID="divorce"
CLIENT_SECRET="thUphEveC2Ekuqedaneh4jEcRuba4t2t"
CURL_OPTS="$CURL_OPTS -S --silent"
code=$(curl ${CURL_OPTS} -u "${IMPORTER_USERNAME}:${IMPORTER_PASSWORD}" -XPOST "${IDAM_URI}/oauth2/authorize?redirect_uri=${REDIRECT_URI}&response_type=code&client_id=${CLIENT_ID}" -d "" | jq -r .code)

curl ${CURL_OPTS} -H "Content-Type: application/x-www-form-urlencoded" -u "${CLIENT_ID}:${CLIENT_SECRET}" -XPOST "${IDAM_URI}/oauth2/token?code=${code}&redirect_uri=${REDIRECT_URI}&grant_type=authorization_code" -d "" | jq -r .access_token

