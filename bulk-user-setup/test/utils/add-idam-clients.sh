#!/usr/bin/env bash

set -eu

dir=$(dirname ${0})

${dir}/idam-create-service.sh "ccd-bulk-user-register" "ccd-bulk-user-register" "${IDAM_BULK_USER_CLIENT_SECRET:?IDAM_BULK_USER_CLIENT_SECRET must be set}" "https://create-bulk-user-test/oauth2redirect" "false" "openid roles create-user manage-user search-user"
