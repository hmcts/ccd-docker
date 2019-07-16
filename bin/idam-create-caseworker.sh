#!/bin/bash
## Usage: ./idam-create-caseworker.sh roles email [password] [surname] [forename]
##
## Options:
##    - role: Comma-separated list of roles. Roles must exist in IDAM (i.e `caseworker-probate,caseworker-probate-solicitor`)
##    - email: Email address
##    - password: User's password. Default to `Pa55word11`. Weak passwords that do not match the password criteria by SIDAM will cause use creation to fail, and such failure may not be expressly communicated to the user. 
##    - surname: Last name. Default to `Test`.
##    - forename: First name. Default to `User`.
##
## Create a CCD caseworker with the roles `caseworker` and all additional roles
## provided in `roles` options.

rolesStr=$1
email=$2
password=${3:-Pa55word11}
surname=${4:-Test}
forename=${5:-User}

if [ -z "$rolesStr" ]
  then
    echo "Usage: ./idam-create-caseworker.sh roles [email] [password] [surname] [forename]"
    exit 1
fi

IFS=',' read -ra roles <<< "$rolesStr"

# Build roles JSON array
rolesJson="["
firstRole=true
for i in "${roles[@]}"; do
  if [ "$firstRole" = false ] ; then
    rolesJson="${rolesJson},"
  fi
  rolesJson=''${rolesJson}'{"code":"'${i}'"}'
  firstRole=false
done
rolesJson="${rolesJson}]"

curl -XPOST \
  http://localhost:5000/testing-support/accounts \
  -H "Content-Type: application/json" \
  -d '{"email":"'${email}'","forename":"'${forename}'","surname":"'${surname}'","password":"'${password}'","levelOfAccess":1, "roles": '${rolesJson}', "userGroup": {"code": "caseworker"}}'
