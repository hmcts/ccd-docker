#!/bin/bash
## Usage: ./document-management-store-get.sh documentId
##
## Get the file from DM store.
## documentId - UUID identifying the resource
##

documentId=$1
dir=$(dirname "$0")

userToken="$(${dir}/utils/idam-user-token.sh)"
serviceToken="$(${dir}/utils/lease-service-token.sh ccd_gw)"

curl --verbose \
  http://localhost:4603/documents/${documentId} \
  -H "Authorization: Bearer ${userToken}" \
  -H "ServiceAuthorization: Bearer ${serviceToken}"
