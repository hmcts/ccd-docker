#!/usr/bin/env bash

set -eu
dir=$(dirname ${0})
jq -r '[(.[] | .roles | split(",")) | .[] ] | unique[]' ${dir}/roles.json | while read args; do
  ${dir}/../../../bin/utils/idam-add-role.sh "$args"
done
