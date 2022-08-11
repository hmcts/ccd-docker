#!/usr/bin/env bash

set -eu

dir=$(dirname ${0})

${dir}/utils/idam-create-service.sh "ccd_gateway" "ccd_gateway" "ccd_gateway_secret" "http://localhost:3451/oauth2redirect" "false" "profile openid roles"

${dir}/utils/idam-create-service.sh "xuiwebapp" "xuiwebapp" "OOOOOOOOOOOOOOOO" "http://localhost:3455/oauth2/callback" "false" "profile openid roles manage-user create-user search-user"

${dir}/utils/idam-create-service.sh "ccd_admin" "ccd_admin" "ccd_admin_secret" "https://localhost:3100/oauth2redirect" "false" "profile openid roles"

${dir}/utils/idam-create-service.sh "am_role_assignment" "am_role_assignment" "am_role_assignment_secret" "http://localhost:4096/oauth2redirect" "false" "profile openid roles search-user"

${dir}/utils/idam-create-service.sh "ccd_data_store_api" "ccd_data_store_api" "idam_data_store_client_secret" "http://ccd-data-store-api/oauth2redirect" "false" "profile openid roles manage-user"

${dir}/utils/idam-create-service.sh "ccd_case_disposer" "ccd_case_disposer" "idam_ccd_case_disposer_secret" "http://ccd-case-disposer/oauth2redirect" "false" "profile openid roles"

${dir}/utils/idam-create-service.sh "ccd_next_hearing_updater_service" "ccd_next_hearing_updater_service" "AAAAAAAAAAAAAAAA" "http://ccd-next-hearing-updater-service/oauth2redirect" "false" "profile openid roles"