#!/usr/bin/env bash

set -eu

userId=${1}
type=${2}
roleName=${3}
classification=${4}
grantType=${5}
roleCategory=${6}
readOnly=${7}
startTime="now()"
endTime="now() + interval '10 years'"
attributes=${8}
authorisations=${9}

psql -h localhost -p ${DB_EXTERNAL_PORT} -d role_assignment -U ccd -c "INSERT INTO role_assignment (id, actor_id_type, actor_id, role_type, role_name, classification, grant_type, role_category, read_only, begin_time, end_time, attributes, created, authorisations) VALUES ('$(uuidgen)', 'IDAM', '${userId}', '${type}', '${roleName}', '${classification}', '${grantType}', '${roleCategory}', ${readOnly}, ${startTime}, ${endTime}, '${attributes}', 'now()', ${authorisations})" -q

psql -h localhost -p ${DB_EXTERNAL_PORT} -d role_assignment -U ccd -c "INSERT INTO actor_cache_control (actor_id, etag, json_response) VALUES ('${userId}', 1, '{}') ON CONFLICT (actor_id) DO UPDATE SET etag = actor_cache_control.etag + 1" -q
