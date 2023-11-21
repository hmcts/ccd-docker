#!/usr/bin/env bash

set -eu

if [ "${ENVIRONMENT:-local}" != "local" ]; then
  exit 0;
fi

dir=$(dirname ${0})

email=${1}

curl --silent --show-error -H 'Content-Type: application/json' \
  ${IDAM_API_BASE_URL:-http://localhost:5000}/testing-support/accounts?email=${email}
