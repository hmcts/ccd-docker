#!/usr/bin/env bash

set -eu

dir=$(dirname ${0})

jq -r '.[] | .email + " " + .roles + " " +  .lastName + " " +  .firstName' ${dir}/users.json | while read args; do
  ${dir}/utils/idam-simulator-create-user.sh $args
done
