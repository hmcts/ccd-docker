#!/usr/bin/env bash
# Check queue polling SQL, returned fields and Elasticsearch version metadata.
# Reads pipeline configuration only; no network calls or database changes.
# Run from the repository root: bash tests/logstash-queue-contract.sh
set -euo pipefail

pipeline=logstash/pipeline/01_input.conf
statement="$(tr '\n' ' ' < "$pipeline")"
output=logstash/pipeline/03_output.conf
expected_returning='q.id AS version, cd.id, created_date, last_modified, jurisdiction, case_type_id, state, last_state_modified_date, data::TEXT AS json_data, data_classification::TEXT AS json_data_classification, reference, security_classification, supplementary_data::TEXT AS json_supplementary_data'

normalise_whitespace() {
  printf '%s' "$1" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'
}

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

returning="${statement#*RETURNING }"
returning="${returning%%\"*}"
[[ "$(normalise_whitespace "$returning")" == "$expected_returning" ]] || {
  echo "$pipeline has an unexpected queue poll RETURNING projection." >&2; exit 1;
}

for required in 'document_id => "%{id}"' 'version => "%{[@metadata][queue_version]}"' 'version_type => "external"'; do
  grep -Fq "$required" "$output" || {
    echo "$output is missing Elasticsearch external-version output: $required" >&2; exit 1;
  }
done

filter=logstash/pipeline/02_filter.conf
rename='rename => { "version" => "[@metadata][queue_version]" }'
grep -Fq "$rename" "$filter" || {
  echo "$filter must move the queue version into metadata." >&2; exit 1;
}
[[ "$(sed '/clone {/,$d' "$filter")" == *"$rename"* ]] || {
  echo "$filter must move the queue version before cloning." >&2; exit 1;
}
