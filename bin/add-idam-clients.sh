#!/usr/bin/env bash

set -eu

dir=$(dirname ${0})

${dir}/utils/idam-create-service.sh "ccd_gateway" "ccd_gateway" "ccd_gateway_secret" "http://localhost:3451/oauth2redirect" "false" "profile openid roles"

${dir}/utils/idam-create-service.sh "xuiwebapp" "xuiwebapp" "xuiwebapp_secrect" "http://localhost:3455/oauth2/callback" "false" "profile openid roles manage-user create-user"
