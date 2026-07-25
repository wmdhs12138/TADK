#!/data/data/com.termux/files/usr/bin/bash

# Shared test-suite runner.
#
# This file is intended to be sourced.
# Do not enable set -e here because it would affect the caller.
#
# Public API:
#   run_test_suite NAME DIRECTORY RUNNER_PATH
#
# Exit codes:
#   0   all discovered tests passed
#   1   no tests found or at least one test failed
#   64  invalid arguments

if [[ -n "${TADK_TEST_SUITE_HELPER_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_TEST_SUITE_HELPER_LOADED=1

run_test_suite() {
    if (( $# != 3 )); then
        printf '%s\n' \
            'run_test_suite: usage: run_test_suite NAME DIRECTORY RUNNER_PATH' \
            >&2
        return 64
    fi

    local suite_name="$1"
    local suite_dir="$2"
    local runner_path="$3"
    local test_file
    local test_name
    local passed=0
    local failed=0
    local -a test_files=()

    if [[ -z "$suite_name" ]]; then
        printf 'run_test_suite: suite name must not be empty\n' >&2
        return 64
    fi

    if [[ ! -d "$suite_dir" ]]; then
        printf 'run_test_suite: suite directory does not exist: %s\n' \
            "$suite_dir" >&2
        return 1
    fi

    while IFS= read -r test_file; do
        [[ "$test_file" == "$runner_path" ]] && continue
        test_files+=("$test_file")
    done < <(
        find "$suite_dir" \
            -maxdepth 1 \
            -type f \
            -name '*.sh' \
            -print |
            sort
    )

    if (( ${#test_files[@]} == 0 )); then
        printf 'No %s test files found in %s\n' \
            "$suite_name" \
            "$suite_dir" >&2
        return 1
    fi

    printf 'TADK %s tests\n%s\n' \
        "$suite_name" \
        '----------------------------------------'

    for test_file in "${test_files[@]}"; do
        test_name="$(basename "$test_file")"
        printf 'RUN  %s\n' "$test_name"

        if bash "$test_file"; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
            printf 'FAIL %s\n' "$test_name" >&2
        fi

        printf '\n'
    done

    printf '%s\nPassed: %s\nFailed: %s\n' \
        '----------------------------------------' \
        "$passed" \
        "$failed"

    if (( failed != 0 )); then
        return 1
    fi

    printf 'All %s tests passed.\n' "$suite_name"
}
