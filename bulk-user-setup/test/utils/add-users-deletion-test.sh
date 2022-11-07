#!/usr/bin/env bash

set -eu

dir=$(dirname ${0})

jq -r '.[] | .email + " " + .roles + " " +  .lastName + " " +  .firstName' ${dir}/users-delete.json | while read args; do
  ${dir}/../../../bin/utils/idam-create-caseworker.sh $args
done
