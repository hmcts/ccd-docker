#!/bin/bash
docker-compose -f compose/backend.yml -f compose/frontend.yml "$@"
