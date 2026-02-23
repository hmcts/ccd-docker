#!/usr/bin/env bash

set -eu

if [ "${ENVIRONMENT:-local}" != "local" ]; then
  exit 0;
fi

dir=$(dirname ${0})

email=${1}

if [ -z "${IDAM_FULL_ENABLED:-}" ]; then
  curl --silent --show-error -H 'Content-Type: application/json' \
    ${IDAM_API_BASE_URL:-http://localhost:5000}/testing-support/accounts?email=${email}

else
  apiToken=$(${dir}/idam-authenticate.sh "${IDAM_ADMIN_USER}" "${IDAM_ADMIN_PASSWORD}")

  curl --silent --show-error -H 'Content-Type: application/json' -H "Authorization: AdminApiAuthToken ${apiToken}" \
    ${IDAM_API_BASE_URL:-http://localhost:5000}/users?email=${email}
fi

