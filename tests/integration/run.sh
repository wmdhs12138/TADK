#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
INTEGRATION_DIR="$TADK_ROOT/tests/integration"
RUNNER_PATH="$INTEGRATION_DIR/run.sh"

TEST_FILES=()

while IFS= read -r test_file; do
    [[ "$test_file" == "$RUNNER_PATH" ]] && continue
    TEST_FILES+=("$test_file")
done < <(
    find "$INTEGRATION_DIR" \
        -maxdepth 1 \
        -type f \
        -name '*.sh' \
        -print |
        sort
)

if (( ${#TEST_FILES[@]} == 0 )); then
    printf 'No integration test files found in %s\n' \
        "$INTEGRATION_DIR" >&2
    exit 1
fi

PASSED=0
FAILED=0

printf 'TADK integration tests\n%s\n' \
    '----------------------------------------'

for test_file in "${TEST_FILES[@]}"; do
    test_name="$(basename "$test_file")"
    printf 'RUN  %s\n' "$test_name"

    if bash "$test_file"; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        printf 'FAIL %s\n' "$test_name" >&2
    fi

    printf '\n'
done

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All integration tests passed.\n'
