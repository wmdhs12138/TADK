#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../helpers/assertions.sh
source "$TADK_ROOT/tests/helpers/assertions.sh"

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

case_register_and_query() {
    source "$TADK_ROOT/lib/workflow.sh"
    sample_step() { :; }

    workflow_register sample sample_step
    workflow_has_step sample
}

case_missing_step_query_fails() {
    source "$TADK_ROOT/lib/workflow.sh"

    local status=0
    workflow_has_step missing || status=$?
    assert_failure "$status" '不存在的步骤查询应失败'
}

case_duplicate_registration_fails() {
    source "$TADK_ROOT/lib/workflow.sh"
    sample_step() { :; }

    workflow_register sample sample_step

    local output status=0
    output="$(workflow_register sample sample_step 2>&1)" || status=$?

    assert_equals '65' "$status" '重复注册应返回 65'
    assert_contains "$output" 'step already registered: sample'
}

case_missing_function_fails() {
    source "$TADK_ROOT/lib/workflow.sh"

    local output status=0
    output="$(workflow_register sample missing_function 2>&1)" || status=$?

    assert_equals '127' "$status" '缺失函数应返回 127'
    assert_contains "$output" 'function not found: missing_function'
}

case_run_preserves_order() {
    source "$TADK_ROOT/lib/workflow.sh"
    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    first_step() { printf 'first\n' >> "$trace_file"; }
    second_step() { printf 'second\n' >> "$trace_file"; }
    third_step() { printf 'third\n' >> "$trace_file"; }

    workflow_register first first_step
    workflow_register second second_step
    workflow_register third third_step
    workflow_run first second third

    local trace
    trace="$(cat "$trace_file")"
    assert_equals $'first\nsecond\nthird' "$trace" '步骤必须按注册名称给出的顺序执行'
}

case_failure_stops_workflow() {
    source "$TADK_ROOT/lib/workflow.sh"
    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    first_step() { printf 'first\n' >> "$trace_file"; }
    failing_step() { printf 'failing\n' >> "$trace_file"; return 23; }
    never_step() { printf 'never\n' >> "$trace_file"; }

    workflow_register first first_step
    workflow_register failing failing_step
    workflow_register never never_step

    local status=0
    workflow_run first failing never || status=$?

    local trace
    trace="$(cat "$trace_file")"
    assert_equals '23' "$status" '工作流应传播失败步骤的退出码'
    assert_equals $'first\nfailing' "$trace" '失败后不得执行后续步骤'
}

case_unknown_step_fails() {
    source "$TADK_ROOT/lib/workflow.sh"

    local output status=0
    output="$(workflow_step unknown 2>&1)" || status=$?

    assert_equals '66' "$status" '未知步骤应返回 66'
    assert_contains "$output" 'unknown step: unknown'
}

case_empty_workflow_fails() {
    source "$TADK_ROOT/lib/workflow.sh"

    local output status=0
    output="$(workflow_run 2>&1)" || status=$?

    assert_equals '64' "$status" '空工作流应返回 64'
    assert_contains "$output" 'requires at least one step'
}

run_case 'register and query step' case_register_and_query
run_case 'missing step query' case_missing_step_query_fails
run_case 'duplicate registration' case_duplicate_registration_fails
run_case 'missing function registration' case_missing_function_fails
run_case 'ordered execution' case_run_preserves_order
run_case 'stop after failure' case_failure_stops_workflow
run_case 'unknown step execution' case_unknown_step_fails
run_case 'empty workflow' case_empty_workflow_fails

printf '%s\nPassed: %d\nFailed: %d\n' '----------------------------------------' "$PASSED" "$FAILED"
(( FAILED == 0 )) || exit 1
printf 'All workflow unit tests passed.\n'
