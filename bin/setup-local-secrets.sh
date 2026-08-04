#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"

environment=${CCD_ENV:-local}
env_file=${CCD_ENV_FILE:-.env}
local_secret_dir=${CCD_LOCAL_SECRETS_DIR:-.local-secrets}

if [[ "$environment" != "local" && "$environment" != "docker" ]]; then
  echo "CCD_ENV=$environment selected; no local secrets will be generated."
  echo "Provide a managed environment file with CCD_ENV_FILE and source it before running Compose."
  exit 0
fi

if [[ -e "$env_file" ]]; then
  echo "Refusing to overwrite existing $env_file. Set CCD_ENV_FILE to another file or remove it deliberately."
  exit 1
fi

command -v openssl >/dev/null 2>&1 || { echo "openssl is required" >&2; exit 1; }

umask 077
mkdir -p "$local_secret_dir"
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout "$local_secret_dir/localhost.key" \
  -out "$local_secret_dir/localhost.crt" \
  -subj '/CN=localhost' >/dev/null 2>&1

generate_local_secret() { openssl rand -hex 32; }
gateway_client_secret=$(generate_local_secret)

cat > "$env_file" <<EOF
# Generated for local CCD development only. Do not commit or reuse outside local Docker.
CCD_ENV=local
S2S_URL_BASE=http://localhost:4502
ELASTIC_SEARCH_FTA_ENABLED=false
HTTPS_CERT_PATH=$repo_dir/$local_secret_dir/localhost.crt
HTTPS_KEY_PATH=$repo_dir/$local_secret_dir/localhost.key
DB_USERNAME=ccd
DB_PASSWORD=$(generate_local_secret)
AM_DB_USERNAME=am
AM_DB_PASSWORD=$(generate_local_secret)
IDAM_KEY_CCD_GATEWAY=$(generate_local_secret)
IDAM_KEY_CCD_ADMIN=$(generate_local_secret)
IDAM_KEY_CCD_DATA_STORE=$(generate_local_secret)
IDAM_KEY_CCD_DEFINITION_STORE=$(generate_local_secret)
IDAM_KEY_CCD_PS=$(generate_local_secret)
IDAM_KEY_CASE_DOCUMENT=$(generate_local_secret)
IDAM_KEY_NEXT_HEARING_UPDATER=$(generate_local_secret)
OAUTH2_CLIENT_CCD_GATEWAY=$gateway_client_secret
OAUTH2_CLIENT_CCD_ADMIN=$(generate_local_secret)
OAUTH2_CLIENT_CCD_DATA_STORE=$(generate_local_secret)
OAUTH2_CLIENT_CCD_CASE_DISPOSER=$(generate_local_secret)
OAUTH2_CLIENT_NEXT_HEARING_DATE_UPDATER=$(generate_local_secret)
OAUTH2_CLIENT_AM_ROLE_ASSIGNMENT=$(generate_local_secret)
OAUTH2_CLIENT_HMC_HMI_INBOUND_ADAPTER=$(generate_local_secret)
BEFTA_OAUTH2_CLIENT_SECRET_OF_XUIWEBAPP=$(generate_local_secret)
BEFTA_S2S_CLIENT_SECRET_OF_XUI_WEBAPP=$(generate_local_secret)
SECURITY_OAUTH2_CLIENT_CLIENTSECRET=$(generate_local_secret)
APPINSIGHTS_INSTRUMENTATIONKEY=local-only
CCD_NEXT_HEARING_DATE_PASSWORD=$(generate_local_secret)
HMC_DB_PASSWORD=$(generate_local_secret)
AM_ROLE_ASSIGNMENT_ADMIN_PWD=$(generate_local_secret)
DATA_STORE_TOKEN_SECRET=$(generate_local_secret)
JWT_KEY=$(generate_local_secret)
SYSTEM_USER_PASSWORD=$(generate_local_secret)
SPRING_DATASOURCE_PASSWORD=$(generate_local_secret)
IDAM_SPI_FORGEROCK_AM_PASSWORD=$(generate_local_secret)
IDAM_SPI_FORGEROCK_IDM_PASSWORD=$(generate_local_secret)
IDAM_SPI_FORGEROCK_IDM_PIN_DEFAULTPASSWORD=$(generate_local_secret)
STORAGEACCOUNT_PRIMARY_CONNECTION_STRING=UseDevelopmentStorage=true
IDAM_DB_PASSWORD=$(generate_local_secret)
CCD_CASEWORKER_DEFAULT_PASSWORD=$(generate_local_secret)
IDAM_USER_PASSWORD=$(generate_local_secret)
IDAM_CLIENT_SECRET=$gateway_client_secret
IDAM_ADMIN_PASSWORD=$(generate_local_secret)
IDAM_ADMIN_USER=ccd.docker.default@hmcts.net
IDAM_KEY_AM_ROLE_ASSIGNMENT=$(generate_local_secret)
IDAM_KEY_AM_ORG_ROLE_MAPPING=$(generate_local_secret)
IDAM_KEY_API_GW=$(generate_local_secret)
IDAM_KEY_API_HMI_INBOUND_ADAPTER=$(generate_local_secret)
IDAM_KEY_BULK_SCAN_ORCHESTRATOR=$(generate_local_secret)
IDAM_KEY_BULK_SCAN_PROCESSOR=$(generate_local_secret)
IDAM_KEY_CCD_CASE_DISPOSER=$(generate_local_secret)
IDAM_KEY_CFT_HEARING_SERVICE=$(generate_local_secret)
IDAM_KEY_DM_STORE=$(generate_local_secret)
IDAM_KEY_FPL_CASE_SERVICE=$(generate_local_secret)
IDAM_KEY_TS_TRANSLATION_SERVICE=$(generate_local_secret)
IDAM_KEY_XUI_WEBAPP=$(generate_local_secret)
BEFTA_S2S_CLIENT_SECRET_OF_AAC_MANAGE_CASE_ASSIGNMENT=$(generate_local_secret)
BEFTA_S2S_CLIENT_SECRET_OF_PAYMENT_APP=$(generate_local_secret)
BEFTA_S2S_CLIENT_ID_OF_XUI_WEBAPP=xuiwebapp
BEFTA_OAUTH2_CLIENT_ID_OF_XUIWEBAPP=xuiwebapp
BEFTA_S2S_CLIENT_ID=ccd_gw
BEFTA_S2S_CLIENT_SECRET=$IDAM_KEY_CCD_GATEWAY
BEFTA_OAUTH2_CLIENT_ID_OF_XUIWEBAPP=xuiwebapp
CCD_API_GATEWAY_OAUTH2_CLIENT_ID=ccd_gateway
CCD_API_GATEWAY_OAUTH2_CLIENT_SECRET=$gateway_client_secret
CCD_API_GATEWAY_S2S_ID=ccd_gw
CCD_API_GATEWAY_S2S_KEY=$IDAM_KEY_CCD_GATEWAY
CCD_GW_SERVICE_SECRET=$IDAM_KEY_CCD_GATEWAY
ROLE_ASSIGNMENT_API_GATEWAY_S2S_CLIENT_KEY=$IDAM_KEY_CCD_GATEWAY
ROLE_ASSIGNMENT_USER_PASSWORD=$(generate_local_secret)
DEFINITION_IMPORTER_PASSWORD=$(generate_local_secret)
TESTING_SUPPORT_ENABLED=true
NOTIFY_HMC_API_KEY=$(generate_local_secret)
NOTIFY_ERROR_TEMPLATE_ID=local-only
NOTIFY_ERROR_EMAIL_ADDRESS=local@example.invalid
NOTIFY_ERROR_REPLY_TO_EMAIL_ADDRESS=local@example.invalid
NOTIFY_AWAITING_ACTUALS_TEMPLATE_ID=local-only
NOTIFY_AWAITING_ACTUALS_EMAIL_ADDRESS=local@example.invalid
NOTIFY_AWAITING_ACTUALS_REPLY_TO_EMAIL_ADDRESS=local@example.invalid
EOF

chmod 600 "$env_file" "$local_secret_dir/localhost.key"
echo "Created local environment file: $env_file"
echo "Created local HTTPS files under: $local_secret_dir"
echo "Load it with: source ./bin/set-environment-variables.sh"
