#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_FILES=(
    "$TADK_ROOT/tests/unit/workflow.sh"
)

PASSED=0
FAILED=0

printf 'TADK unit tests\n%s\n' '----------------------------------------'

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

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' "$PASSED" "$FAILED"

(( FAILED == 0 )) || exit 1
printf 'All unit tests passed.\n'
