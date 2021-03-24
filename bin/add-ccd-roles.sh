#!/usr/bin/env bash

set -eu
dir=$(dirname ${0})
jq -c '(.[])' ${dir}/ccd-roles.json | while read args; do
  role=$(jq -r '.role' <<< $args)
  class=$(jq -r '.security_classification' <<< $args)
  echo Creating/updating CCD role $role with classification $class
  ${dir}/ccd-add-role.sh $role $class
  echo
done
