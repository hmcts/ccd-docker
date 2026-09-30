#!/usr/bin/env bash
# Stop Logstash before updating Data Store, then recreate Logstash with its
# readiness gate to prevent queue polling during migrations.
# Pause case-writing traffic/jobs and verify release cutover checks first.
# Run from the repository root: bash bin/upgrade-data-store-logstash.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# Abort on any failure, leaving Logstash stopped if Data Store cannot be upgraded.
./ccd compose stop -t 120 ccd-logstash
./ccd compose up -d ccd-data-store-api
./ccd compose up -d --no-deps --force-recreate ccd-logstash
# The Logstash startup gate waits for migrations/readiness before starting any pipeline.
