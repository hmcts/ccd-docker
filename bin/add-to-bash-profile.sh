#!/usr/bin/env bash

PROFILE="${HOME}/.bash_profile"
LINE="source ${PWD}/bin/set-environment-variables.sh"

if ! grep -Fqx "$LINE" "$PROFILE" 2>/dev/null; then
  echo -e "\n$LINE\n" >> "$PROFILE"
  echo "Added to $PROFILE"
else
  echo "Already present in $PROFILE"
fi
