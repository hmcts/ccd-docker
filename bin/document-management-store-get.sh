#!/bin/bash
## Usage: ./document-management-store-get.sh documentId
##
## Get the file from DM store.
## documentId - UUID identifying the resource
##

documentId=$1
binFolder=$(dirname "$0")

userToken="$(${binFolder}/idam-user-token.sh)"
serviceToken="$(${binFolder}/idam-service-token.sh ccd_gw)"

curl --verbose \
  http://localhost:4603/documents/${documentId} \
  -H "Authorization: Bearer ${userToken}" \
  -H "ServiceAuthorization: Bearer ${serviceToken}"
