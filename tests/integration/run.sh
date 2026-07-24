#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_FILES=(
    "$TADK_ROOT/tests/integration/apk-command.sh"
    "$TADK_ROOT/tests/integration/build-command.sh"
    "$TADK_ROOT/tests/integration/install-command.sh"
    "$TADK_ROOT/tests/integration/launch-command.sh"
    "$TADK_ROOT/tests/integration/logcat-command.sh"
    "$TADK_ROOT/tests/integration/dev-command.sh"
)
PASSED=0 FAILED=0
printf 'TADK integration tests\n%s\n' '----------------------------------------'
for test_file in "${TEST_FILES[@]}"; do
    test_name="$(basename "$test_file")"
    printf 'RUN  %s\n' "$test_name"
    if "$test_file"; then PASSED=$((PASSED + 1)); else FAILED=$((FAILED + 1)); printf 'FAIL %s\n' "$test_name" >&2; fi
    printf '\n'
done
printf '%s\nPassed: %s\nFailed: %s\n' '----------------------------------------' "$PASSED" "$FAILED"
(( FAILED == 0 )) || exit 1
printf 'All integration tests passed.\n'
