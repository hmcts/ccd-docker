#!/usr/bin/env bash
# Verify Data Store readiness gates Logstash startup and upgrades stop
# the existing consumer before updating Data Store.
# This prevents queue processing during Flyway migrations.
#
# Uses mocks; no Docker containers, network calls or database changes.
# Run from the repository root: bash tests/logstash-startup.sh
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/project/bin"
export STARTUP_TEST_STATE="$work/state"
export STARTUP_TEST_EXEC="$work/executed"
export PATH="$work/bin:$PATH"
cat > "$work/bin/curl" <<'MOCK'
#!/usr/bin/env bash
n=$(cat "$STARTUP_TEST_STATE" 2>/dev/null || echo 0)
echo $((n + 1)) > "$STARTUP_TEST_STATE"
[[ ${STARTUP_TEST_FAIL:-false} != true && $n -ge 2 ]]
MOCK
cat > "$work/bin/sleep" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
cat > "$work/bin/logstash" <<'MOCK'
#!/usr/bin/env bash
[[ $(cat "$STARTUP_TEST_STATE") -ge 3 ]]
echo started > "$STARTUP_TEST_EXEC"
MOCK
chmod +x "$work/bin/"*
sed 's|/usr/share/logstash/bin/logstash|logstash|' logstash/wait-for-data-store.sh > "$work/wait.sh"
bash "$work/wait.sh" 2>/dev/null
[[ -f "$STARTUP_TEST_EXEC" && $(cat "$STARTUP_TEST_STATE") == 3 ]]
rm "$STARTUP_TEST_EXEC" "$STARTUP_TEST_STATE"
if STARTUP_TEST_FAIL=true bash "$work/wait.sh" 2>/dev/null; then
  echo 'Unready Data Store must prevent Logstash startup' >&2; exit 1
fi
[[ ! -e "$STARTUP_TEST_EXEC" && $(cat "$STARTUP_TEST_STATE") == 120 ]]

cp bin/upgrade-data-store-logstash.sh "$work/project/bin/"
export STARTUP_TEST_CALLS="$work/calls"
cat > "$work/project/ccd" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STARTUP_TEST_CALLS"
if [[ ${STARTUP_TEST_FAIL:-false} == true && "$*" == 'compose up -d ccd-data-store-api' ]]; then
  exit 1
fi
MOCK
chmod +x "$work/project/ccd"
bash "$work/project/bin/upgrade-data-store-logstash.sh"
printf '%s\n' 'compose stop -t 120 ccd-logstash' 'compose up -d ccd-data-store-api' \
  'compose up -d --no-deps --force-recreate ccd-logstash' > "$work/expected"
diff -u "$work/expected" "$STARTUP_TEST_CALLS"
rm "$STARTUP_TEST_CALLS"
if STARTUP_TEST_FAIL=true bash "$work/project/bin/upgrade-data-store-logstash.sh"; then
  echo 'Failed upgrade must not restart Logstash' >&2; exit 1
fi
[[ $(wc -l < "$STARTUP_TEST_CALLS" | tr -d ' ') == 2 ]]
echo 'Logstash startup and upgrade ordering tests passed.'
