#!/bin/bash
## Usage: ./idam-delete-caseworker.sh email
##
## Options:
##    - email: Email address
##

email=$1

# Build roles JSON array

curl -XDELETE "${IDAM_API_BASE_URL:-http://localhost:5000}/testing-support/accounts/${email}" -H "Content-Type: application/json"
