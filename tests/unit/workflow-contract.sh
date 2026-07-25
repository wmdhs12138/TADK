#!/usr/bin/env bash
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

case_public_api_surface() {
    source "$TADK_ROOT/lib/workflow.sh"

    local function_name
    for function_name in \
        workflow_register \
        workflow_register_if \
        workflow_before \
        workflow_after \
        workflow_has_step \
        workflow_step \
        workflow_run
    do
        declare -F "$function_name" >/dev/null 2>&1 ||
            return 1
    done
}

case_error_code_contract() {
    source "$TADK_ROOT/lib/workflow.sh"

    sample_step() { :; }

    local status=0

    workflow_register sample sample_step

    workflow_register sample sample_step >/dev/null 2>&1 || status=$?
    assert_equals '65' "$status" 'duplicate registration must return 65' ||
        return 1

    status=0
    workflow_step missing >/dev/null 2>&1 || status=$?
    assert_equals '66' "$status" 'unknown step must return 66' ||
        return 1

    status=0
    workflow_register 'invalid.name' sample_step >/dev/null 2>&1 || status=$?
    assert_equals '64' "$status" 'invalid arguments must return 64' ||
        return 1

    status=0
    workflow_register other missing_function >/dev/null 2>&1 || status=$?
    assert_equals '127' "$status" 'missing functions must return 127'
}

case_condition_hook_contract() {
    source "$TADK_ROOT/lib/workflow.sh"

    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    condition_passes() {
        printf 'condition\n' >> "$trace_file"
    }

    before_hook() {
        printf 'before\n' >> "$trace_file"
    }

    sample_step() {
        printf 'step\n' >> "$trace_file"
    }

    after_hook() {
        printf 'after\n' >> "$trace_file"
    }

    workflow_register_if sample condition_passes sample_step
    workflow_before sample before_hook
    workflow_after sample after_hook
    workflow_step sample

    assert_equals \
        $'condition\nbefore\nstep\nafter' \
        "$(cat "$trace_file")" \
        'workflow order must be condition, before, step, after'
}

case_condition_skip_contract() {
    source "$TADK_ROOT/lib/workflow.sh"

    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    condition_fails() {
        printf 'condition\n' >> "$trace_file"
        return 1
    }

    skipped_step() {
        printf 'skipped\n' >> "$trace_file"
    }

    following_step() {
        printf 'following\n' >> "$trace_file"
    }

    workflow_register_if conditional condition_fails skipped_step
    workflow_register following following_step
    workflow_run conditional following

    assert_equals \
        $'condition\nfollowing' \
        "$(cat "$trace_file")" \
        'a false condition must skip one step and continue'
}

case_fail_fast_contract() {
    source "$TADK_ROOT/lib/workflow.sh"

    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    first_step() {
        printf 'first\n' >> "$trace_file"
    }

    failing_step() {
        printf 'failing\n' >> "$trace_file"
        return 23
    }

    never_step() {
        printf 'never\n' >> "$trace_file"
    }

    workflow_register first first_step
    workflow_register failing failing_step
    workflow_register never never_step

    local status=0
    workflow_run first failing never || status=$?

    assert_equals '23' "$status" 'workflow_run must preserve the failing code' ||
        return 1
    assert_equals \
        $'first\nfailing' \
        "$(cat "$trace_file")" \
        'workflow_run must stop after the first failure'
}

run_case 'public API surface' case_public_api_surface
run_case 'error code contract' case_error_code_contract
run_case 'condition and hook contract' case_condition_hook_contract
run_case 'condition skip contract' case_condition_skip_contract
run_case 'fail-fast contract' case_fail_fast_contract

printf \
    '%s\nPassed: %d\nFailed: %d\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All workflow contract tests passed.\n'
