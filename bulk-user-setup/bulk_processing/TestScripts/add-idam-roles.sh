#!/usr/bin/env bash

set -eu
dir=$(dirname ${0})
jq -r '[(.[] | .roles | split(",")) | .[] ] | unique[]' ${dir}/users-1.json | while read args; do
  ${dir}/TestScripts/idam-add-role.sh "$args"
done
