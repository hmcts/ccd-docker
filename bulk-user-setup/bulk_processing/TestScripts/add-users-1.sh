#!/usr/bin/env bash

set -eu

dir=$(dirname ${0})

jq -r '.[] | .email + " " + .roles + " " +  .lastName + " " +  .firstName' ${dir}/users-1.json | while read args; do
  ${dir}/TestScripts/idam-create-caseworker.sh $args
done
