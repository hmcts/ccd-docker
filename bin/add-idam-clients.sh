#!/usr/bin/env bash

set -eu

dir=$(dirname ${0})

gateway_secret=${OAUTH2_CLIENT_CCD_GATEWAY:?OAUTH2_CLIENT_CCD_GATEWAY must be set}
xui_secret=${BEFTA_OAUTH2_CLIENT_SECRET_OF_XUIWEBAPP:?BEFTA_OAUTH2_CLIENT_SECRET_OF_XUIWEBAPP must be set}
admin_secret=${OAUTH2_CLIENT_CCD_ADMIN:?OAUTH2_CLIENT_CCD_ADMIN must be set}
role_assignment_secret=${OAUTH2_CLIENT_AM_ROLE_ASSIGNMENT:?OAUTH2_CLIENT_AM_ROLE_ASSIGNMENT must be set}
data_store_secret=${OAUTH2_CLIENT_CCD_DATA_STORE:?OAUTH2_CLIENT_CCD_DATA_STORE must be set}
case_disposer_secret=${OAUTH2_CLIENT_CCD_CASE_DISPOSER:?OAUTH2_CLIENT_CCD_CASE_DISPOSER must be set}
next_hearing_secret=${OAUTH2_CLIENT_NEXT_HEARING_DATE_UPDATER:?OAUTH2_CLIENT_NEXT_HEARING_DATE_UPDATER must be set}
hmi_inbound_secret=${OAUTH2_CLIENT_HMC_HMI_INBOUND_ADAPTER:?OAUTH2_CLIENT_HMC_HMI_INBOUND_ADAPTER must be set}

${dir}/utils/idam-create-service.sh "ccd_gateway" "ccd_gateway" "${gateway_secret}" "http://localhost:3451/oauth2redirect" "false" "profile openid roles"

${dir}/utils/idam-create-service.sh "xuiwebapp" "xuiwebapp" "${xui_secret}" "http://localhost:3455/oauth2/callback" "false" "profile openid roles manage-user create-user search-user"

${dir}/utils/idam-create-service.sh "ccd_admin" "ccd_admin" "${admin_secret}" "https://localhost:3100/oauth2redirect" "false" "profile openid roles"

${dir}/utils/idam-create-service.sh "am_role_assignment" "am_role_assignment" "${role_assignment_secret}" "http://localhost:4096/oauth2redirect" "false" "profile openid roles search-user"

${dir}/utils/idam-create-service.sh "ccd_data_store_api" "ccd_data_store_api" "${data_store_secret}" "http://ccd-data-store-api/oauth2redirect" "false" "profile openid roles manage-user"

${dir}/utils/idam-create-service.sh "ccd_case_disposer" "ccd_case_disposer" "${case_disposer_secret}" "http://ccd-case-disposer/oauth2redirect" "false" "profile openid roles"

${dir}/utils/idam-create-service.sh "ccd_next_hearing_date_updater" "ccd_next_hearing_date_updater" "${next_hearing_secret}" "http://ccd-next-hearing-date-updater/oauth2redirect" "false" "profile openid roles"

${dir}/utils/idam-create-service.sh "hmc_hmi_inbound_adapter" "hmc_hmi_inbound_adapter" "${hmi_inbound_secret}" "https://hmi-inbound-adapter/oauth2redirect" "false" "profile openid roles manage-user"
