#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

TEST_FILES=(
    "$TADK_ROOT/tests/integration/apk-command.sh"
    "$TADK_ROOT/tests/integration/install-command.sh"
    "$TADK_ROOT/tests/integration/launch-command.sh"
)

PASSED=0
FAILED=0

printf 'TADK integration tests\n'
printf '%s\n' '----------------------------------------'

for test_file in "${TEST_FILES[@]}"; do
    test_name="$(basename "$test_file")"

    printf 'RUN  %s\n' "$test_name"

    if "$test_file"; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        printf 'FAIL %s\n' "$test_name" >&2
    fi

    printf '\n'
done

printf '%s\n' '----------------------------------------'
printf 'Passed: %s\n' "$PASSED"
printf 'Failed: %s\n' "$FAILED"

if (( FAILED > 0 )); then
    exit 1
fi

printf 'All integration tests passed.\n'
