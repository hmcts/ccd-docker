#!/usr/bin/env bash

set -eu

dir=$(dirname ${0})

jq -r '.[] | .email + " " + .roles + " " +  .lastName + " " +  .firstName + " " +  .active' ${dir}/users.json | while read args; do
  ${dir}/idam-create-caseworker.sh $args
done
