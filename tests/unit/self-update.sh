#!/usr/bin/env bash

set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
TEST_HOME="$TEST_ROOT/home"

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/self_update.sh"

cleanup() {
    rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT

mkdir -p "$TEST_HOME"
export HOME="$TEST_HOME"

printf 'TEST self-update cache is rooted under HOME\n'
cache_root="$(tadk_self_update_cache_root)"
assert_equals \
    "$TEST_HOME/.cache/tadk/self-update" \
    "$cache_root" \
    'self-update temporary state must use the HOME cache root'
if [[ ! -d "$cache_root" ]]; then
    printf 'ASSERT DIRECTORY EXISTS FAILED: %s\n' \
        'self-update cache root should be created on demand' >&2
    exit 1
fi
printf 'PASS self-update cache is rooted under HOME\n\n'

printf 'TEST self-update path safety resolves outside backup paths\n'
mkdir -p "$TEST_ROOT/target"
resolved_backup="$(tadk_self_update_resolve_path "$TEST_ROOT/target/../backup")"
assert_equals \
    "$TEST_ROOT/backup" \
    "$resolved_backup" \
    'backup path resolution should normalize parent traversal'
printf 'PASS self-update path safety resolves outside backup paths\n\n'

printf 'TEST --apply requires an exact SHA-256 argument\n'
set +e
argument_output="$("$TADK_ROOT/bin/tadk" self-update --apply missing.zip --json 2>&1)"
argument_status="$?"
set -e
assert_equals '64' "$argument_status" \
    '--apply without --sha256 should return a usage error'
assert_contains "$argument_output" \
    '{"version":1' \
    'argument errors with --json should remain versioned JSON'
assert_contains "$argument_output" \
    '"name":"argument","status":"fail"' \
    'argument errors should identify the failed requirement'
assert_not_contains "$argument_output" \
    'TADK Self-update' \
    'JSON argument errors must not contain text headings'
printf 'PASS --apply requires an exact SHA-256 argument\n\n'

printf 'PASS: self-update unit tests\n'
