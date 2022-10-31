#!/usr/bin/env bash

set -eu

dir=$(dirname ${0})


${dir}/idam-create-service.sh "ccd-bulk-user-management" "ccd-bulk-user-management" "ccd_bulk_user_management_secret" "https://create-bulk-user-test/oauth2redirect" "false" "openid roles create-user manage-user search-user"
