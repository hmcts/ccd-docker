#!/bin/bash

if [ -f .tags.env ]; then
  source .tags.env
fi

docker-compose -f compose/backend.yml -f compose/frontend.yml "$@"
