#!/usr/bin/env bash
# Wait for Data Store migrations and readiness before starting Logstash.
# Exit after 120 failed checks so queue polling cannot start prematurely.
# Used as the container entrypoint; forwards all arguments to Logstash.
set -euo pipefail

# Flyway finishes before the application exposes its readiness endpoint.
for ((attempt = 1; attempt <= 120; attempt++)); do
  if curl --fail --silent --show-error --connect-timeout 2 --max-time 5 \
      http://ccd-data-store-api:4452/health/readiness > /dev/null; then
    exec /usr/share/logstash/bin/logstash "$@"
  fi
  echo "Waiting for Data Store migrations and readiness ($attempt/120)..." >&2
  sleep 2
done

echo "Data Store did not become ready; Logstash polling has not started." >&2
exit 1
