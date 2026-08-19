#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BULK_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

cd "$BULK_DIR"

if [ -z "${TERM:-}" ] || [ "$TERM" = "dumb" ]; then
  export TERM=xterm
fi

source ./bulk-user-setup.sh

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

LOGFILE="$tmpdir/dispatcher.log"
LOGLEVEL="ERROR"
is_test=true
ENABLE_CASEWORKER_CHECKS=false
ENABLE_USERID_REGISTRATIONS=false
filename="dispatcher-smoke.csv"
filepath_output_newpath="$tmpdir/output.csv"

touch "$LOGFILE"
: > "$filepath_output_newpath"

handler_calls=()

function record_handler() {
  local handler=$1

  handler_calls+=("$handler")
  inviteStatus="SUCCESS"
  responseMessage="$handler"
  output_csv="${operation},${email},${handler}"
}

# Override handlers so the smoke test validates dispatch without calling IDAM.
function fail_invalid_operation() { record_handler "fail_invalid_operation"; }
function fail_invalid_email() { record_handler "fail_invalid_email"; }
function fail_no_roles_defined() { record_handler "fail_no_roles_defined"; }
function fail_invalid_role_string() { record_handler "fail_invalid_role_string"; }
function fail_sso_user_not_found() { record_handler "fail_sso_user_not_found"; }
function fail_find_user_not_found() { record_handler "fail_find_user_not_found"; }
function handle_find_user() { record_handler "handle_find_user"; }
function handle_add_with_userid_registration() { record_handler "handle_add_with_userid_registration"; }
function handle_add_new_user() { record_handler "handle_add_new_user"; }
function handle_add_roles_to_existing_user() { record_handler "handle_add_roles_to_existing_user"; }
function handle_delete_user_account() { record_handler "handle_delete_user_account"; }
function handle_suspend_user() { record_handler "handle_suspend_user"; }
function handle_unsuspend_user() { record_handler "handle_unsuspend_user"; }
function handle_update_email() { record_handler "handle_update_email"; }
function handle_update_name() { record_handler "handle_update_name"; }
function handle_missing_user_for_operation() { record_handler "handle_missing_user_for_operation"; }
function fail_manual_role_delete_request() { record_handler "fail_manual_role_delete_request"; }
function handle_delete_roles() { record_handler "handle_delete_roles"; }
function handle_already_processed_record() { record_handler "handle_already_processed_record"; }

function lookup_user_for_record() {
  ENABLE_USERID_REGISTRATIONS=false
  rawReturnedValue="HTTP-404"
  outputSSOId=" "
  userId="test-user-id"
  userActiveState="true"
  firstNameFromApi="${firstName}"
  lastNameFromApi="${lastName}"
  usersRolesFromApi='["caseworker","caseworker-role-one"]'
  lastModified="2026-01-01T00:00:00Z"

  if [[ "$email" == userid.* ]]; then
    ENABLE_USERID_REGISTRATIONS=true
  fi

  if [ "$csvSSOId" != "null" ]; then
    outputSSOId="$csvSSOId"
    if [[ "$csvSSOId" == missing* ]]; then
      return
    fi
  fi

  if [[ "$email" == missing.* ]]; then
    return
  fi

  rawReturnedValue='{"id":"test-user-id","active":"true","email":"found.user@hmcts.gov.uk","forename":"First","surname":"Last","roles":["caseworker","caseworker-role-one"],"lastModified":"2026-01-01T00:00:00Z"}'
}

fixture="$tmpdir/dispatcher.csv"
cat > "$fixture" <<'CSV'
operation,email,firstName,lastName,roles,id,ssoId,status,result
unknown,found.invalid-op@hmcts.gov.uk,First,Last,caseworker-role-one,,,,
add,invalid-email,First,Last,caseworker-role-one,,,,
add,found.no-roles@hmcts.gov.uk,First,Last,,,,,
add,found.bad-role@hmcts.gov.uk,First,Last,caseworker+bad,,,,
find,found.sso@hmcts.gov.uk,First,Last,caseworker-role-one,,missing-sso,,
find,missing.find@hmcts.gov.uk,First,Last,,,,,
find,found.find@hmcts.gov.uk,First,Last,,,,,
add,userid.add@hmcts.gov.uk,First,Last,caseworker-role-one,test-user-id,,,
add,missing.add-new@hmcts.gov.uk,First,Last,caseworker-role-one,,,,
add,found.add-existing@hmcts.gov.uk,First,Last,caseworker-role-one,,,,
deleteuser,found.delete-user@hmcts.gov.uk,First,Last,,,,,
suspend,found.suspend@hmcts.gov.uk,First,Last,,,,,
unsuspend,found.unsuspend@hmcts.gov.uk,First,Last,,,,,
updateemail,found.update-email@hmcts.gov.uk,First,Last,,,,,
updatename,found.update-name@hmcts.gov.uk,First,Last,,,,,
delete,missing.delete@hmcts.gov.uk,First,Last,caseworker-role-one,,,,
delete,found.delete-manual@hmcts.gov.uk,First,Last,judiciary,,,,
delete,found.delete-roles@hmcts.gov.uk,First,Last,caseworker-role-one,,,,
add,found.already-processed@hmcts.gov.uk,First,Last,caseworker-role-one,,,SUCCESS,
CSV

expected_handlers=(
  fail_invalid_operation
  fail_invalid_email
  fail_no_roles_defined
  fail_invalid_role_string
  fail_sso_user_not_found
  fail_find_user_not_found
  handle_find_user
  handle_add_with_userid_registration
  handle_add_new_user
  handle_add_roles_to_existing_user
  handle_delete_user_account
  handle_suspend_user
  handle_unsuspend_user
  handle_update_email
  handle_update_name
  handle_missing_user_for_operation
  fail_manual_role_delete_request
  handle_delete_roles
  handle_already_processed_record
)

json=$(convert_input_file_to_json "$fixture")
reset_processing_counters

while IFS= read -r user; do
  process_user_record "$user"
done < <(echo "$json" | jq -r -c '.[]')

if [ "${#handler_calls[@]}" -ne "${#expected_handlers[@]}" ]; then
  echo "Expected ${#expected_handlers[@]} handler calls, got ${#handler_calls[@]}"
  printf 'Actual calls:\n%s\n' "${handler_calls[@]}"
  exit 1
fi

for index in "${!expected_handlers[@]}"; do
  if [ "${handler_calls[$index]}" != "${expected_handlers[$index]}" ]; then
    echo "Mismatch at case $((index + 1)): expected ${expected_handlers[$index]}, got ${handler_calls[$index]}"
    exit 1
  fi
done

echo "Dispatcher smoke test passed (${#expected_handlers[@]} cases)."
