#!/bin/bash
## Usage: ./idam-simulator-create-user.sh email roles [surname] [forename] [password]
##
## Options:
##    - email: Email address
##    - role: Comma-separated list of roles.
##    - surname: Last name. Default to `Test`.
##    - forename: First name. Default to `User`.
##    - password: User's password. Default to `Pa55word11`.

email=$1
rolesStr=$2
surname=${3:-Test}
forename=${4:-User}
password=${5:-Pa55word11}
idamUrl=${IDAM_API_URL_BASE:-http://localhost:5000}

if [ -z "$rolesStr" ]
  then
    echo "Usage: ./idam-simulator-create-user.sh email roles [surname] [forename] [password]"
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

echo "Creating user $email"

curl -XPOST \
  "${idamUrl}"/testing-support/accounts \
  -H "Content-Type: application/json" \
  -d '{"email":"'${email}'","forename":"'${forename}'","surname":"'${surname}'","password":"'${password}'", "roles": '${rolesJson}'}'