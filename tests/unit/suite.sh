#!/data/data/com.termux/files/usr/bin/bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/tests/helpers/suite.sh"

PASSED=0
FAILED=0

run_case() {
    local name="$1"
    shift

    printf 'TEST %s\n' "$name"

    if ( "$@" ); then
        PASSED=$((PASSED + 1))
        printf 'PASS %s\n\n' "$name"
    else
        FAILED=$((FAILED + 1))
        printf 'FAIL %s\n\n' "$name" >&2
    fi
}

create_test_script() {
    local path="$1"
    local body="$2"

    cat > "$path" <<EOF_SCRIPT
#!/usr/bin/env bash
$body
EOF_SCRIPT

    chmod +x "$path"
}

case_requires_three_arguments() {
    local output status=0

    output="$(run_test_suite unit 2>&1)" || status=$?

    assert_equals '64' "$status"
    assert_contains "$output" \
        'usage: run_test_suite NAME DIRECTORY RUNNER_PATH'
}

case_empty_name_fails() {
    local suite_dir output status=0

    suite_dir="$(mktemp -d)"
    trap 'rm -rf "$suite_dir"' RETURN

    output="$(
        run_test_suite '' "$suite_dir" "$suite_dir/run.sh" 2>&1
    )" || status=$?

    assert_equals '64' "$status"
    assert_contains "$output" 'suite name must not be empty'
}

case_missing_directory_fails() {
    local missing_dir output status=0

    missing_dir="$(mktemp -u)"

    output="$(
        run_test_suite unit "$missing_dir" "$missing_dir/run.sh" 2>&1
    )" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" 'suite directory does not exist'
    assert_contains "$output" "$missing_dir"
}

case_empty_suite_fails() {
    local suite_dir output status=0

    suite_dir="$(mktemp -d)"
    trap 'rm -rf "$suite_dir"' RETURN

    output="$(
        run_test_suite unit "$suite_dir" "$suite_dir/run.sh" 2>&1
    )" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" 'No unit test files found'
    assert_contains "$output" "$suite_dir"
}

case_runner_is_excluded() {
    local suite_dir runner_path output status=0

    suite_dir="$(mktemp -d)"
    trap 'rm -rf "$suite_dir"' RETURN

    runner_path="$suite_dir/run.sh"

    create_test_script \
        "$runner_path" \
        "printf 'runner-should-not-run\n'; exit 99"

    create_test_script \
        "$suite_dir/example.sh" \
        "printf 'example-ran\n'"

    output="$(
        run_test_suite unit "$suite_dir" "$runner_path" 2>&1
    )" || status=$?

    assert_success "$status"
    assert_contains "$output" 'example-ran'
    assert_not_contains "$output" 'runner-should-not-run'
    assert_contains "$output" 'Passed: 1'
    assert_contains "$output" 'Failed: 0'
}

case_tests_run_in_sorted_order() {
    local suite_dir runner_path output status=0

    suite_dir="$(mktemp -d)"
    trap 'rm -rf "$suite_dir"' RETURN

    runner_path="$suite_dir/run.sh"

    create_test_script \
        "$suite_dir/z-last.sh" \
        "printf 'z-last-ran\n'"

    create_test_script \
        "$suite_dir/a-first.sh" \
        "printf 'a-first-ran\n'"

    create_test_script \
        "$suite_dir/m-middle.sh" \
        "printf 'm-middle-ran\n'"

    output="$(
        run_test_suite unit "$suite_dir" "$runner_path" 2>&1
    )" || status=$?

    assert_success "$status"
    assert_order "$output" 'RUN  a-first.sh' 'RUN  m-middle.sh'
    assert_order "$output" 'RUN  m-middle.sh' 'RUN  z-last.sh'
    assert_contains "$output" 'Passed: 3'
    assert_contains "$output" 'Failed: 0'
}

case_non_executable_script_runs_through_bash() {
    local suite_dir runner_path test_path output status=0

    suite_dir="$(mktemp -d)"
    trap 'rm -rf "$suite_dir"' RETURN

    runner_path="$suite_dir/run.sh"
    test_path="$suite_dir/non-executable.sh"

    create_test_script \
        "$test_path" \
        "printf 'non-executable-ran\n'"

    chmod -x "$test_path"

    output="$(
        run_test_suite unit "$suite_dir" "$runner_path" 2>&1
    )" || status=$?

    assert_success "$status"
    assert_contains "$output" 'non-executable-ran'
    assert_contains "$output" 'Passed: 1'
}

case_failure_is_counted_and_suite_continues() {
    local suite_dir runner_path output status=0

    suite_dir="$(mktemp -d)"
    trap 'rm -rf "$suite_dir"' RETURN

    runner_path="$suite_dir/run.sh"

    create_test_script \
        "$suite_dir/a-pass.sh" \
        "printf 'first-pass\n'"

    create_test_script \
        "$suite_dir/b-fail.sh" \
        "printf 'middle-fail\n'; exit 23"

    create_test_script \
        "$suite_dir/c-pass.sh" \
        "printf 'last-pass\n'"

    output="$(
        run_test_suite unit "$suite_dir" "$runner_path" 2>&1
    )" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" 'first-pass'
    assert_contains "$output" 'middle-fail'
    assert_contains "$output" 'last-pass'
    assert_contains "$output" 'FAIL b-fail.sh'
    assert_contains "$output" 'Passed: 2'
    assert_contains "$output" 'Failed: 1'
    assert_not_contains "$output" 'All unit tests passed.'
}

case_success_summary_is_printed() {
    local suite_dir runner_path output status=0

    suite_dir="$(mktemp -d)"
    trap 'rm -rf "$suite_dir"' RETURN

    runner_path="$suite_dir/run.sh"

    create_test_script \
        "$suite_dir/example.sh" \
        "printf 'successful-test\n'"

    output="$(
        run_test_suite integration "$suite_dir" "$runner_path" 2>&1
    )" || status=$?

    assert_success "$status"
    assert_contains "$output" 'TADK integration tests'
    assert_contains "$output" 'All integration tests passed.'
}

run_case \
    'requires three arguments' \
    case_requires_three_arguments

run_case \
    'empty suite name fails' \
    case_empty_name_fails

run_case \
    'missing suite directory fails' \
    case_missing_directory_fails

run_case \
    'empty suite fails' \
    case_empty_suite_fails

run_case \
    'runner file is excluded' \
    case_runner_is_excluded

run_case \
    'tests run in sorted order' \
    case_tests_run_in_sorted_order

run_case \
    'non-executable script runs through Bash' \
    case_non_executable_script_runs_through_bash

run_case \
    'failure is counted and suite continues' \
    case_failure_is_counted_and_suite_continues

run_case \
    'success summary is printed' \
    case_success_summary_is_printed

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All suite helper unit tests passed.\n'
