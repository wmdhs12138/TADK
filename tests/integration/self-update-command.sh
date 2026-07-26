#!/usr/bin/env bash

set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
MOCK_BIN="$TEST_ROOT/bin"
FIXTURE_ROOT="$TEST_ROOT/TADK-0.3.0-alpha.19"
OVERWRITE_FIXTURE_ROOT="$TEST_ROOT/overwrite-fixture/TADK-0.3.0-alpha.19"
SIGNAL_FIXTURE_ROOT="$TEST_ROOT/signal-fixture/TADK-0.3.0-alpha.19"
ARCHIVE="$TEST_ROOT/TADK-0.3.0-alpha.19-update.zip"
TEST_HOME="$TEST_ROOT/home"

source "$TADK_ROOT/tests/helpers/assertions.sh"

cleanup() {
    rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

mkdir -p \
    "$MOCK_BIN" \
    "$FIXTURE_ROOT/release" \
    "$OVERWRITE_FIXTURE_ROOT/release" \
    "$SIGNAL_FIXTURE_ROOT/release" \
    "$TEST_HOME"

export HOME="$TEST_HOME"

printf '0.3.0-alpha.19\n' > "$FIXTURE_ROOT/VERSION"
sed 's/0\.3\.0-alpha\.18/0.3.0-alpha.19/g' \
    "$TADK_ROOT/release/manifest.json" \
    > "$FIXTURE_ROOT/release/manifest.json"

for consistency_file in \
    README.md \
    RELEASE_NOTES.md \
    VERIFY.md \
    CHANGELOG.md; do
    sed 's/0\.3\.0-alpha\.18/0.3.0-alpha.19/g' \
        "$TADK_ROOT/$consistency_file" \
        > "$FIXTURE_ROOT/$consistency_file"
done

cp -a "$FIXTURE_ROOT"/. "$OVERWRITE_FIXTURE_ROOT"/
mkdir -p "$OVERWRITE_FIXTURE_ROOT/commands" "$OVERWRITE_FIXTURE_ROOT/lib"
cp "$TADK_ROOT/commands/self-update.sh" \
    "$OVERWRITE_FIXTURE_ROOT/commands/self-update.sh"
cp "$TADK_ROOT/lib/self_update.sh" \
    "$OVERWRITE_FIXTURE_ROOT/lib/self_update.sh"
printf '\n# self-update integration overwrite marker\n' \
    >> "$OVERWRITE_FIXTURE_ROOT/commands/self-update.sh"
printf '\n# self-update integration overwrite marker\n' \
    >> "$OVERWRITE_FIXTURE_ROOT/lib/self_update.sh"

cp -a "$FIXTURE_ROOT"/. "$SIGNAL_FIXTURE_ROOT"/
mkdir -p "$SIGNAL_FIXTURE_ROOT/tests"
printf '#!/usr/bin/env bash\nsleep 5\n' \
    > "$SIGNAL_FIXTURE_ROOT/tests/smoke.sh"
chmod +x "$SIGNAL_FIXTURE_ROOT/tests/smoke.sh"

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

prepare_git_target() {
    local target="$1"

    cp -a "$TADK_ROOT" "$target"
    rm -rf -- "$target/.git"
    git -C "$target" init -q 2>/dev/null
    git -C "$target" config user.email tadk-tests@example.invalid
    git -C "$target" config user.name TADK-tests
    git -C "$target" add -A 2>/dev/null
    git -C "$target" commit -qm 'test fixture baseline' 2>/dev/null
}

printf 'TEST self-update applies transactionally and preserves user state\n'

APPLY_TARGET="$TEST_ROOT/apply-target"
APPLY_BACKUP="$TEST_ROOT/apply-backup"
prepare_git_target "$APPLY_TARGET"
mkdir -p "$APPLY_TARGET/.tadk" "$APPLY_TARGET/build"
printf 'project=keep\n' > "$APPLY_TARGET/.tadk/project.conf"
printf 'build-cache\n' > "$APPLY_TARGET/build/cache.txt"
printf 'keystore\n' > "$APPLY_TARGET/release-signing.keystore"
git -C "$APPLY_TARGET" add -A 2>/dev/null
git -C "$APPLY_TARGET" commit -qm 'test preserved state' 2>/dev/null

set +e
apply_output="$(
    "$APPLY_TARGET/bin/tadk" \
        self-update \
        --apply "$ARCHIVE" \
        --sha256 "$expected_sha256" \
        --backup-dir "$APPLY_BACKUP" \
        2>&1
)"
apply_status="$?"
set -e

assert_equals '0' "$apply_status" \
    'valid apply should commit the transaction'
assert_contains "$apply_output" \
    'PASS apply_copy' \
    'apply should copy the validated payload'
assert_contains "$apply_output" \
    'self-update apply transaction committed' \
    'apply should report a committed transaction'
assert_equals '0.3.0-alpha.19' "$(tr -d '\r\n' < "$APPLY_TARGET/VERSION")" \
    'apply should install the archive VERSION'
assert_file_exists "$APPLY_TARGET/.tadk/project.conf" \
    'apply should preserve .tadk state'
assert_file_exists "$APPLY_TARGET/build/cache.txt" \
    'apply should preserve build cache'
assert_file_exists "$APPLY_TARGET/release-signing.keystore" \
    'apply should preserve keystores'
assert_equals '0.3.0-alpha.18' "$(tr -d '\r\n' < "$APPLY_BACKUP/VERSION")" \
    'backup should contain the complete original installation'
assert_file_exists "$APPLY_BACKUP/.tadk/project.conf" \
    'backup should contain preserved .tadk state'
assert_file_not_exists "$TEST_HOME/.cache/tadk/self-update/update.lock" \
    'lock should be cleaned after a committed apply'

printf 'PASS self-update applies transactionally and preserves user state\n\n'

printf 'TEST self-update applies a payload that overwrites its own updater\n'

OVERWRITE_TARGET="$TEST_ROOT/overwrite-target"
OVERWRITE_BACKUP="$TEST_ROOT/overwrite-backup"
prepare_git_target "$OVERWRITE_TARGET"
export SELF_UPDATE_FIXTURE_ROOT="$OVERWRITE_FIXTURE_ROOT"

set +e
overwrite_output="$(
    "$OVERWRITE_TARGET/bin/tadk" \
        self-update \
        --apply "$ARCHIVE" \
        --sha256 "$expected_sha256" \
        --backup-dir "$OVERWRITE_BACKUP" \
        --json \
        2>&1
)"
overwrite_status="$?"
set -e

export SELF_UPDATE_FIXTURE_ROOT="$FIXTURE_ROOT"

assert_equals '0' "$overwrite_status" \
    'self-overwrite apply should commit the complete transaction'
assert_equals '1' "$(printf '%s\n' "$overwrite_output" | awk 'NF { count += 1 } END { print count + 0 }')" \
    'self-overwrite JSON output should contain exactly one object'
assert_contains "$overwrite_output" \
    '"name":"apply","status":"pass"' \
    'self-overwrite apply should report a committed transaction'
assert_contains "$(< "$OVERWRITE_TARGET/commands/self-update.sh")" \
    'self-update integration overwrite marker' \
    'self-overwrite apply should install commands/self-update.sh'
assert_contains "$(< "$OVERWRITE_TARGET/lib/self_update.sh")" \
    'self-update integration overwrite marker' \
    'self-overwrite apply should install lib/self_update.sh'
assert_file_not_exists "$TEST_HOME/.cache/tadk/self-update/update.lock" \
    'self-overwrite apply should clean the transaction lock'

printf 'PASS self-update applies a payload that overwrites its own updater\n\n'

printf 'TEST self-update EXIT handler rolls back after TERM\n'

SIGNAL_TARGET="$TEST_ROOT/signal-target"
SIGNAL_BACKUP="$TEST_ROOT/signal-backup"
SIGNAL_OUTPUT_FILE="$TEST_ROOT/signal-output"
prepare_git_target "$SIGNAL_TARGET"
export SELF_UPDATE_FIXTURE_ROOT="$SIGNAL_FIXTURE_ROOT"

set +e
"$SIGNAL_TARGET/bin/tadk" \
    self-update \
    --apply "$ARCHIVE" \
    --sha256 "$expected_sha256" \
    --backup-dir "$SIGNAL_BACKUP" \
    --json \
    > "$SIGNAL_OUTPUT_FILE" \
    2>&1 &
signal_pid="$!"
set -e

for attempt in {1..100}; do
    if [[ -f "$SIGNAL_BACKUP/VERSION" &&
          "$(tr -d '\r\n' < "$SIGNAL_TARGET/VERSION" 2>/dev/null)" == \
          '0.3.0-alpha.19' ]]; then
        break
    fi
    sleep 0.1
done

set +e
kill -TERM "$signal_pid"
wait "$signal_pid"
signal_status="$?"
set -e

signal_output="$(< "$SIGNAL_OUTPUT_FILE")"

export SELF_UPDATE_FIXTURE_ROOT="$FIXTURE_ROOT"

assert_equals '143' "$signal_status" \
    'TERM should preserve the unified termination status'
assert_equals '1' "$(printf '%s\n' "$signal_output" | awk 'NF { count += 1 } END { print count + 0 }')" \
    'TERM handling should emit exactly one JSON object'
assert_contains "$signal_output" \
    '"name":"signal","status":"fail"' \
    'TERM should be reported in the JSON checks'
assert_contains "$signal_output" \
    '"name":"rollback","status":"pass"' \
    'EXIT handling should complete automatic rollback after TERM'
assert_equals '0.3.0-alpha.18' "$(tr -d '\r\n' < "$SIGNAL_TARGET/VERSION")" \
    'TERM should restore the original installation'
assert_file_not_exists "$TEST_HOME/.cache/tadk/self-update/update.lock" \
    'TERM handling should clean the transaction lock'

printf 'PASS self-update EXIT handler rolls back after TERM\n\n'

printf 'TEST self-update rejects concurrent transactions\n'

LOCK_DIR="$TEST_HOME/.cache/tadk/self-update/update.lock"
LOCK_BACKUP="$TEST_ROOT/lock-backup"
mkdir -p "$LOCK_DIR"
printf 'held-by-test\n' > "$LOCK_DIR/pid"

set +e
lock_output="$(
    "$APPLY_TARGET/bin/tadk" \
        self-update \
        --apply "$ARCHIVE" \
        --sha256 "$expected_sha256" \
        --backup-dir "$LOCK_BACKUP" \
        --json \
        2>&1
)"
lock_status="$?"
set -e

assert_equals '1' "$lock_status" \
    'an existing update lock should reject a concurrent apply'
assert_contains "$lock_output" \
    'another self-update transaction is already in progress' \
    'concurrent apply rejection should be explicit'
assert_file_not_exists "$LOCK_BACKUP" \
    'concurrent apply rejection must happen before backup creation'
rm -rf -- "$LOCK_DIR"

printf 'PASS self-update rejects concurrent transactions\n\n'

printf 'TEST self-update automatically rolls back after smoke failure\n'

ROLLBACK_TARGET="$TEST_ROOT/rollback-target"
ROLLBACK_BACKUP="$TEST_ROOT/rollback-backup"
prepare_git_target "$ROLLBACK_TARGET"
printf '\nexit 7\n' >> "$ROLLBACK_TARGET/tests/smoke.sh"
git -C "$ROLLBACK_TARGET" add tests/smoke.sh 2>/dev/null
git -C "$ROLLBACK_TARGET" commit -qm 'test failing smoke baseline' 2>/dev/null
original_smoke_sha256="$(sha256sum "$ROLLBACK_TARGET/tests/smoke.sh" | awk '{print $1}')"

set +e
rollback_output="$(
    "$ROLLBACK_TARGET/bin/tadk" \
        self-update \
        --apply "$ARCHIVE" \
        --sha256 "$expected_sha256" \
        --backup-dir "$ROLLBACK_BACKUP" \
        --json \
        2>&1
)"
rollback_status="$?"
set -e

assert_equals '7' "$rollback_status" \
    'smoke failure should fail the apply transaction'
assert_contains "$rollback_output" \
    '"name":"rollback","status":"pass"' \
    'smoke failure should report a successful automatic rollback'
assert_not_contains "$rollback_output" \
    'TADK Self-update Apply' \
    'JSON apply output must not contain text headings'
assert_equals '0.3.0-alpha.18' "$(tr -d '\r\n' < "$ROLLBACK_TARGET/VERSION")" \
    'rollback should restore the original VERSION'
assert_equals "$original_smoke_sha256" "$(sha256sum "$ROLLBACK_TARGET/tests/smoke.sh" | awk '{print $1}')" \
    'rollback should restore the complete installation'
assert_file_exists "$ROLLBACK_BACKUP/VERSION" \
    'rollback should retain the complete backup for diagnostics'
assert_file_not_exists "$TEST_HOME/.cache/tadk/self-update/update.lock" \
    'lock should be cleaned after automatic rollback'

printf 'PASS self-update automatically rolls back after smoke failure\n\n'

printf 'TEST self-update rejects a dirty Git worktree before backup\n'

DIRTY_TARGET="$TEST_ROOT/dirty-target"
DIRTY_BACKUP="$TEST_ROOT/dirty-backup"
prepare_git_target "$DIRTY_TARGET"
printf 'local change\n' >> "$DIRTY_TARGET/VERSION"
dirty_version_sha256="$(sha256sum "$DIRTY_TARGET/VERSION" | awk '{print $1}')"

set +e
dirty_output="$(
    "$DIRTY_TARGET/bin/tadk" \
        self-update \
        --apply "$ARCHIVE" \
        --sha256 "$expected_sha256" \
        --backup-dir "$DIRTY_BACKUP" \
        --json \
        2>&1
)"
dirty_status="$?"
set -e

assert_equals '1' "$dirty_status" \
    'dirty Git worktree should reject apply'
assert_contains "$dirty_output" \
    'Git worktree is dirty' \
    'dirty Git worktree rejection should be explicit'
assert_equals "$dirty_version_sha256" "$(sha256sum "$DIRTY_TARGET/VERSION" | awk '{print $1}')" \
    'dirty worktree rejection must not modify the target'
assert_file_not_exists "$DIRTY_BACKUP" \
    'dirty worktree rejection must happen before backup creation'

printf 'PASS self-update rejects a dirty Git worktree before backup\n\n'

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
