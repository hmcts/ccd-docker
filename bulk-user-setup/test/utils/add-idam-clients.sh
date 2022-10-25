#!/usr/bin/env bash

set -eu

dir=$(dirname ${0})


${dir}/idam-create-service.sh "ccd_bulk_user_register" "ccd_bulk_user_register" "ccd_bulk_user_register_secret" "https://create-bulk-user-test/oauth2redirect" "false" "create-user manage-user"
