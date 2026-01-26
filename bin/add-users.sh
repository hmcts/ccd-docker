#!/usr/bin/env bash

set -eu

dir=$(dirname ${0})


if [ -z "${IDAM_FULL_ENABLED:-}" ]; then
  echo "IDAM_FULL_ENABLED is not set. Using IDAN-SIM as default."
  jq -r '.[] | .email + " " + .roles + " " +  .lastName + " " +  .firstName' ${dir}/users.json | while read args; do
    ${dir}/utils/idam-simulator-create-user.sh $args
  done
else
  echo "IDAM_OVERRIDE_URL is set. Using IDAM url : ${IDAM_OVERRIDE_URL}"
  jq -r '.[] | .email + " " + .roles + " " +  .lastName + " " +  .firstName' ${dir}/users.json | while read args; do
    ${dir}/utils/idam-create-caseworker.sh $args
  done
fi
