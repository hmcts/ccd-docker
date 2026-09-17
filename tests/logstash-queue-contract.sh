#!/usr/bin/env bash
set -euo pipefail

pipeline=logstash/pipeline/01_input.conf
statement="$(tr '\n' ' ' < "$pipeline")"

for required in 'WITH candidates AS' 'ORDER BY q.id' 'FOR UPDATE SKIP LOCKED' \
    'LIMIT 1000' 'DELETE FROM case_data_logstash_queue q' \
    'RETURNING q.id AS version' 'q.case_data_id = cd.id'; do
  [[ "$statement" == *"$required"* ]] || {
    echo "$pipeline is missing: $required" >&2; exit 1;
  }
done

[[ "$statement" != *'marked_by_logstash'* ]] || {
  echo "$pipeline still uses marked_by_logstash." >&2; exit 1;
}
