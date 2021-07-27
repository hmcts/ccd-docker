#!/bin/sh

set -eu

USERNAME=${1:-fr_applicant_sol@sharklasers.com}
PASSWORD=${2:-Testing1234}
IDAM_API_BASE_URL=${IDAM_STUB_LOCALHOST:-https://idam-api.aat.platform.hmcts.net}

curl --show-error --header 'Content-Type: application/x-www-form-urlencoded' -H 'Accept: application/json' -d "username=${USERNAME}&password=${PASSWORD}" "${IDAM_API_BASE_URL:-http://localhost:5000}/loginUser" | docker run --rm --interactive stedolan/jq -r .api_auth_token
