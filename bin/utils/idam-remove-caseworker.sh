#!/usr/bin/env bash

######################
## FUNCTIONS
######################

remove_user_request() {
  response=$(curl --insecure --show-error --silent --output /dev/null --write-out "%{http_code}" -X DELETE \
    "${IDAM_API_BASE_URL:-http://localhost:5000}"/testing-support/accounts/"${email}")
  echo "$response"
}

set -eu

if [ "${ENVIRONMENT:-local}" != "local" ]; then
  exit 0;
fi

email=${1}

printf "\n%s%s\n" "Removing IDAM user: " "${email}"

userRemovalResponse=$(remove_user_request)

if [[ $userRemovalResponse -ne 204 ]]; then
  printf "%s%s\n" "Unexpected HTTP status code from IDAM: " "${userRemovalResponse}"
  exit 1
else
  printf "%s%s%s\n" "User " "${email}" " - removed from IDAM"
fi
