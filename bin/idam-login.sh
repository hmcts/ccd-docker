#!/bin/bash
## Usage: ./idam-login.sh email [password]
##
## Options:
##    - email: Email address
##    - password: User's password. Default to `password`.
##
## Login an IDAM user using Basic auth.

email=$1
password=${2:-password}

if [ -z "$email" ]
  then
    echo "Usage: ./idam-login.sh email [password]"
    exit 1
fi

authString=$(echo -n "$email:$password" | base64)

curl -XPOST \
  http://localhost:4501/oauth2/authorize \
  -H "Authorization: Basic ${authString}"
