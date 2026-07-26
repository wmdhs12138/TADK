#!/usr/bin/env bash

set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
MOCK_BIN="$TEST_ROOT/bin"
FIXTURE_ROOT="$TEST_ROOT/TADK-0.3.0-alpha.19"
ARCHIVE="$TEST_ROOT/TADK-0.3.0-alpha.19-update.zip"

source "$TADK_ROOT/tests/helpers/assertions.sh"

cleanup() {
    rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

mkdir -p \
    "$MOCK_BIN" \
    "$FIXTURE_ROOT/release"

printf '0.3.0-alpha.19\n' > "$FIXTURE_ROOT/VERSION"
sed 's/0\.3\.0-alpha\.18/0.3.0-alpha.19/g' \
    "$TADK_ROOT/release/manifest.json" \
    > "$FIXTURE_ROOT/release/manifest.json"

printf 'mock archive payload\n' > "$ARCHIVE"

cat > "$MOCK_BIN/unzip" <<'MOCK_UNZIP'
#!/usr/bin/env bash

set -Eeuo pipefail

archive="${1:-}"
destination="${3:-}"

[[ -f "$archive" ]] || exit 2
[[ "${2:-}" == '-d' ]] || exit 2
[[ -n "$destination" ]] || exit 2

cp -a "$SELF_UPDATE_FIXTURE_ROOT" "$destination"/
MOCK_UNZIP

chmod +x "$MOCK_BIN/unzip"
export SELF_UPDATE_FIXTURE_ROOT="$FIXTURE_ROOT"
export PATH="$MOCK_BIN:$PATH"

expected_sha256="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
original_version_sha256="$(sha256sum "$TADK_ROOT/VERSION" | awk '{print $1}')"

printf 'TEST self-update preflight succeeds in read-only mode\n'

output="$(
    "$TADK_ROOT/bin/tadk" \
        self-update \
        --check "$ARCHIVE" \
        --sha256 "$expected_sha256" \
        2>&1
)"

assert_contains "$output" \
    'PASS archive_extract' \
    'valid archive should be extracted in a temporary directory'
assert_contains "$output" \
    'self-update preflight passed' \
    'valid archive should pass the preflight'

current_version_sha256="$(sha256sum "$TADK_ROOT/VERSION" | awk '{print $1}')"
assert_equals \
    "$original_version_sha256" \
    "$current_version_sha256" \
    'preflight must not modify the current TADK installation'

printf 'PASS self-update preflight succeeds in read-only mode\n\n'

printf 'TEST self-update JSON output is stable\n'

json_output="$(
    "$TADK_ROOT/bin/tadk" \
        self-update \
        --check "$ARCHIVE" \
        --sha256 "$expected_sha256" \
        --json \
        2>&1
)"

assert_contains "$json_output" \
    '"version":1' \
    'JSON should expose the schema version'
assert_contains "$json_output" \
    '"status":"pass"' \
    'valid JSON preflight should pass'
assert_contains "$json_output" \
    '"type":"update"' \
    'JSON should identify an update archive'
assert_contains "$json_output" \
    '"name":"package_contract","status":"pass"' \
    'JSON should report the package contract check'
assert_not_contains "$json_output" \
    'TADK Self-update Preflight' \
    'JSON should not contain text headings'

printf 'PASS self-update JSON output is stable\n\n'

printf 'TEST self-update warns when checksum is omitted\n'

set +e
warning_output="$(
    "$TADK_ROOT/bin/tadk" \
        self-update \
        --check "$ARCHIVE" \
        --json \
        2>&1
)"
warning_status="$?"
set -e

assert_equals '0' "$warning_status" \
    'omitting the expected checksum should be a non-blocking warning'
assert_contains "$warning_output" \
    '"status":"warn"' \
    'missing expected checksum should produce warn status'
assert_contains "$warning_output" \
    '"name":"checksum","status":"warn"' \
    'JSON should identify the checksum warning'

printf 'PASS self-update warns when checksum is omitted\n\n'

printf 'TEST self-update rejects a checksum mismatch\n'

set +e
failure_output="$(
    "$TADK_ROOT/bin/tadk" \
        self-update \
        --check "$ARCHIVE" \
        --sha256 0000000000000000000000000000000000000000000000000000000000000000 \
        --json \
        2>&1
)"
failure_status="$?"
set -e

assert_equals '1' "$failure_status" \
    'checksum mismatch should fail the preflight'
assert_contains "$failure_output" \
    '"status":"fail"' \
    'checksum mismatch should produce fail status'
assert_contains "$failure_output" \
    '"name":"checksum","status":"fail"' \
    'JSON should identify the checksum failure'

printf 'PASS self-update rejects a checksum mismatch\n\n'

printf 'TEST self-update rejects protected paths\n'

mkdir -p "$FIXTURE_ROOT/.tadk"
printf 'version=1\n' > "$FIXTURE_ROOT/.tadk/project.conf"

set +e
protected_output="$(
    "$TADK_ROOT/bin/tadk" \
        self-update \
        --check "$ARCHIVE" \
        --sha256 "$expected_sha256" \
        --json \
        2>&1
)"
protected_status="$?"
set -e

assert_equals '1' "$protected_status" \
    'protected paths should fail the preflight'
assert_contains "$protected_output" \
    '"name":"preserved_paths","status":"fail"' \
    'JSON should identify protected paths'

printf 'PASS self-update rejects protected paths\n\n'

printf 'TEST self-update rejects invalid arguments\n'

set +e
invalid_output="$("$TADK_ROOT/bin/tadk" self-update --check "$ARCHIVE" --sha256 bad 2>&1)"
invalid_status="$?"
set -e

assert_equals '64' "$invalid_status" \
    'invalid checksum syntax should return usage error 64'
assert_contains "$invalid_output" \
    '64 hexadecimal characters' \
    'invalid checksum should explain the required format'

printf 'PASS self-update rejects invalid arguments\n\n'

printf 'PASS: self-update command integration\n'
