#!/usr/bin/env bash
set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../helpers/assertions.sh
source "$TADK_ROOT/tests/helpers/assertions.sh"

# shellcheck source=../helpers/process.sh
source "$TADK_ROOT/tests/helpers/process.sh"

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

    first_step() {
        printf 'first\n' >> "$trace_file"
    }

    second_step() {
        printf 'second\n' >> "$trace_file"
    }

    third_step() {
        printf 'third\n' >> "$trace_file"
    }

    workflow_register first first_step
    workflow_register second second_step
    workflow_register third third_step

    workflow_run first second third

    local trace
    trace="$(cat "$trace_file")"

    assert_equals \
        $'first\nsecond\nthird' \
        "$trace" \
        '步骤必须按给出的顺序执行'
}

case_failure_stops_workflow() {
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

    local trace
    trace="$(cat "$trace_file")"

    assert_equals '23' "$status" '工作流应传播失败步骤的退出码'
    assert_equals \
        $'first\nfailing' \
        "$trace" \
        '失败后不得执行后续步骤'
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

case_before_hooks_preserve_order() {
    source "$TADK_ROOT/lib/workflow.sh"

    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    first_before() {
        printf 'before-1\n' >> "$trace_file"
    }

    second_before() {
        printf 'before-2\n' >> "$trace_file"
    }

    sample_step() {
        printf 'step\n' >> "$trace_file"
    }

    workflow_register sample sample_step
    workflow_before sample first_before
    workflow_before sample second_before

    workflow_step sample

    local trace
    trace="$(cat "$trace_file")"

    assert_equals \
        $'before-1\nbefore-2\nstep' \
        "$trace" \
        'before hooks 必须按注册顺序在主体前执行'
}

case_after_hooks_preserve_order() {
    source "$TADK_ROOT/lib/workflow.sh"

    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    sample_step() {
        printf 'step\n' >> "$trace_file"
    }

    first_after() {
        printf 'after-1\n' >> "$trace_file"
    }

    second_after() {
        printf 'after-2\n' >> "$trace_file"
    }

    workflow_register sample sample_step
    workflow_after sample first_after
    workflow_after sample second_after

    workflow_step sample

    local trace
    trace="$(cat "$trace_file")"

    assert_equals \
        $'step\nafter-1\nafter-2' \
        "$trace" \
        'after hooks 必须按注册顺序在主体后执行'
}

case_before_failure_skips_step_and_after_hooks() {
    source "$TADK_ROOT/lib/workflow.sh"

    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    failing_before() {
        printf 'before-failing\n' >> "$trace_file"
        return 31
    }

    never_before() {
        printf 'before-never\n' >> "$trace_file"
    }

    sample_step() {
        printf 'step-never\n' >> "$trace_file"
    }

    never_after() {
        printf 'after-never\n' >> "$trace_file"
    }

    workflow_register sample sample_step
    workflow_before sample failing_before
    workflow_before sample never_before
    workflow_after sample never_after

    local status=0
    workflow_step sample || status=$?

    local trace
    trace="$(cat "$trace_file")"

    assert_equals '31' "$status" 'before hook 失败码应向上传播'
    assert_equals \
        'before-failing' \
        "$trace" \
        'before hook 失败后不得执行其余 hook、主体和 after hook'
}

case_step_failure_skips_after_hooks() {
    source "$TADK_ROOT/lib/workflow.sh"

    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    before_hook() {
        printf 'before\n' >> "$trace_file"
    }

    failing_step() {
        printf 'step-failing\n' >> "$trace_file"
        return 32
    }

    never_after() {
        printf 'after-never\n' >> "$trace_file"
    }

    workflow_register sample failing_step
    workflow_before sample before_hook
    workflow_after sample never_after

    local status=0
    workflow_step sample || status=$?

    local trace
    trace="$(cat "$trace_file")"

    assert_equals '32' "$status" '主体函数失败码应向上传播'
    assert_equals \
        $'before\nstep-failing' \
        "$trace" \
        '主体失败后不得执行 after hooks'
}

case_after_failure_stops_remaining_hooks_and_workflow() {
    source "$TADK_ROOT/lib/workflow.sh"

    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    first_step() {
        printf 'first-step\n' >> "$trace_file"
    }

    failing_after() {
        printf 'after-failing\n' >> "$trace_file"
        return 33
    }

    never_after() {
        printf 'after-never\n' >> "$trace_file"
    }

    never_step() {
        printf 'second-step-never\n' >> "$trace_file"
    }

    workflow_register first first_step
    workflow_register second never_step
    workflow_after first failing_after
    workflow_after first never_after

    local status=0
    workflow_run first second || status=$?

    local trace
    trace="$(cat "$trace_file")"

    assert_equals '33' "$status" 'after hook 失败码应向上传播'
    assert_equals \
        $'first-step\nafter-failing' \
        "$trace" \
        'after hook 失败后不得执行剩余 hook 和后续步骤'
}

case_hook_registration_requires_known_step() {
    source "$TADK_ROOT/lib/workflow.sh"

    sample_hook() { :; }

    local before_output after_output
    local before_status=0
    local after_status=0

    before_output="$(workflow_before missing sample_hook 2>&1)" \
        || before_status=$?

    after_output="$(workflow_after missing sample_hook 2>&1)" \
        || after_status=$?

    assert_equals '66' "$before_status" '未知步骤不能注册 before hook'
    assert_equals '66' "$after_status" '未知步骤不能注册 after hook'
    assert_contains "$before_output" 'unknown step: missing'
    assert_contains "$after_output" 'unknown step: missing'
}

case_hook_registration_requires_existing_function() {
    source "$TADK_ROOT/lib/workflow.sh"

    sample_step() { :; }

    workflow_register sample sample_step

    local before_output after_output
    local before_status=0
    local after_status=0

    before_output="$(workflow_before sample missing_hook 2>&1)" \
        || before_status=$?

    after_output="$(workflow_after sample missing_hook 2>&1)" \
        || after_status=$?

    assert_equals '127' "$before_status" '缺失的 before hook 函数应返回 127'
    assert_equals '127' "$after_status" '缺失的 after hook 函数应返回 127'
    assert_contains "$before_output" 'function not found: missing_hook'
    assert_contains "$after_output" 'function not found: missing_hook'
}

case_hook_argument_validation() {
    source "$TADK_ROOT/lib/workflow.sh"

    local before_output after_output
    local before_status=0
    local after_status=0

    before_output="$(workflow_before only-one-argument 2>&1)" \
        || before_status=$?

    after_output="$(workflow_after 2>&1)" \
        || after_status=$?

    assert_equals '64' "$before_status" 'before hook 参数错误应返回 64'
    assert_equals '64' "$after_status" 'after hook 参数错误应返回 64'
    assert_contains "$before_output" 'usage: workflow_before STEP FUNCTION'
    assert_contains "$after_output" 'usage: workflow_after STEP FUNCTION'
}

case_conditional_step_runs_when_condition_passes() {
    source "$TADK_ROOT/lib/workflow.sh"

    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    condition_passes() {
        printf 'condition\n' >> "$trace_file"
        return 0
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

    local trace
    trace="$(cat "$trace_file")"

    assert_equals \
        $'condition\nbefore\nstep\nafter' \
        "$trace" \
        '条件满足时应执行 before hook、主体和 after hook'
}

case_conditional_step_skips_when_condition_fails() {
    source "$TADK_ROOT/lib/workflow.sh"

    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    condition_fails() {
        printf 'condition\n' >> "$trace_file"
        return 1
    }

    never_before() {
        printf 'before-never\n' >> "$trace_file"
    }

    never_step() {
        printf 'step-never\n' >> "$trace_file"
    }

    never_after() {
        printf 'after-never\n' >> "$trace_file"
    }

    following_step() {
        printf 'following\n' >> "$trace_file"
    }

    workflow_register_if conditional condition_fails never_step
    workflow_before conditional never_before
    workflow_after conditional never_after
    workflow_register following following_step

    workflow_run conditional following

    local trace
    trace="$(cat "$trace_file")"

    assert_equals \
        $'condition\nfollowing' \
        "$trace" \
        '条件不满足时应跳过整个步骤并继续执行后续步骤'
}

case_conditional_registration_validates_functions() {
    source "$TADK_ROOT/lib/workflow.sh"

    sample_condition() { :; }
    sample_step() { :; }

    local condition_output step_output
    local condition_status=0
    local step_status=0

    condition_output="$(
        workflow_register_if sample missing_condition sample_step 2>&1
    )" || condition_status=$?

    step_output="$(
        workflow_register_if sample sample_condition missing_step 2>&1
    )" || step_status=$?

    assert_equals '127' "$condition_status" \
        '缺失条件函数应返回 127'

    assert_equals '127' "$step_status" \
        '缺失步骤函数应返回 127'

    assert_contains \
        "$condition_output" \
        'function not found: missing_condition'

    assert_contains \
        "$step_output" \
        'function not found: missing_step'
}

case_conditional_registration_rejects_duplicate_step() {
    source "$TADK_ROOT/lib/workflow.sh"

    sample_condition() { :; }
    sample_step() { :; }

    workflow_register sample sample_step

    local output status=0
    output="$(
        workflow_register_if sample sample_condition sample_step 2>&1
    )" || status=$?

    assert_equals '65' "$status" \
        '条件步骤重复注册应返回 65'

    assert_contains "$output" \
        'step already registered: sample'
}

case_conditional_registration_argument_validation() {
    source "$TADK_ROOT/lib/workflow.sh"

    local output status=0
    output="$(workflow_register_if sample condition 2>&1)" || status=$?

    assert_equals '64' "$status" \
        '条件步骤参数错误应返回 64'

    assert_contains \
        "$output" \
        'usage: workflow_register_if STEP CONDITION_FUNCTION FUNCTION'
}

case_unavailable_condition_function_fails_at_runtime() {
    source "$TADK_ROOT/lib/workflow.sh"

    sample_condition() { :; }
    sample_step() { :; }

    workflow_register_if sample sample_condition sample_step
    unset -f sample_condition

    local output status=0
    output="$(workflow_step sample 2>&1)" || status=$?

    assert_equals '127' "$status" \
        '运行时缺失条件函数应返回 127'

    assert_contains \
        "$output" \
        'registered function is unavailable: sample_condition'
}

case_conditional_skip_is_safe_with_errexit() {
    source "$TADK_ROOT/lib/workflow.sh"

    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    condition_fails() {
        printf 'condition\n' >> "$trace_file"
        return 1
    }

    never_step() {
        printf 'never\n' >> "$trace_file"
    }

    following_step() {
        printf 'following\n' >> "$trace_file"
    }

    workflow_register_if conditional condition_fails never_step
    workflow_register following following_step

    (
        set -e
        workflow_run conditional following
    )

    local trace
    trace="$(cat "$trace_file")"

    assert_equals \
        $'condition\nfollowing' \
        "$trace" \
        'set -e 下条件不满足也应安全跳过并继续 workflow'
}

case_before_failure_is_explicit_with_errexit() {
    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    run_bash_errexit '
        source "$1/lib/workflow.sh"
        trace_file="$2"

        failing_before() {
            printf "before-failing\\n" >> "$trace_file"
            return 41
        }

        never_step() {
            printf "step-never\\n" >> "$trace_file"
        }

        workflow_register sample never_step
        workflow_before sample failing_before
        workflow_step sample
    ' "$TADK_ROOT" "$trace_file"

    assert_equals \
        '41' \
        "$RUN_STATUS" \
        'set -e 下 before hook 失败码应保持不变'

    assert_equals \
        'before-failing' \
        "$(cat "$trace_file")" \
        'set -e 下 before hook 失败后不得执行主体'
}

case_step_failure_is_explicit_with_errexit() {
    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    run_bash_errexit '
        source "$1/lib/workflow.sh"
        trace_file="$2"

        failing_step() {
            printf "step-failing\\n" >> "$trace_file"
            return 42
        }

        never_after() {
            printf "after-never\\n" >> "$trace_file"
        }

        workflow_register sample failing_step
        workflow_after sample never_after
        workflow_step sample
    ' "$TADK_ROOT" "$trace_file"

    assert_equals \
        '42' \
        "$RUN_STATUS" \
        'set -e 下步骤主体失败码应保持不变'

    assert_equals \
        'step-failing' \
        "$(cat "$trace_file")" \
        'set -e 下主体失败后不得执行 after hook'
}

case_after_failure_is_explicit_with_errexit() {
    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    run_bash_errexit '
        source "$1/lib/workflow.sh"
        trace_file="$2"

        sample_step() {
            printf "step\\n" >> "$trace_file"
        }

        failing_after() {
            printf "after-failing\\n" >> "$trace_file"
            return 43
        }

        never_after() {
            printf "after-never\\n" >> "$trace_file"
        }

        workflow_register sample sample_step
        workflow_after sample failing_after
        workflow_after sample never_after
        workflow_step sample
    ' "$TADK_ROOT" "$trace_file"

    assert_equals \
        '43' \
        "$RUN_STATUS" \
        'set -e 下 after hook 失败码应保持不变'

    assert_equals \
        $'step\nafter-failing' \
        "$(cat "$trace_file")" \
        'set -e 下 after hook 失败后不得执行剩余 hook'
}

case_workflow_failure_is_explicit_with_errexit() {
    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    run_bash_errexit '
        source "$1/lib/workflow.sh"
        trace_file="$2"

        first_step() {
            printf "first\\n" >> "$trace_file"
        }

        failing_step() {
            printf "failing\\n" >> "$trace_file"
            return 44
        }

        never_step() {
            printf "never\\n" >> "$trace_file"
        }

        workflow_register first first_step
        workflow_register failing failing_step
        workflow_register never never_step
        workflow_run first failing never
    ' "$TADK_ROOT" "$trace_file"

    assert_equals \
        '44' \
        "$RUN_STATUS" \
        'set -e 下 workflow_run 应传播原始失败码'

    assert_equals \
        $'first\nfailing' \
        "$(cat "$trace_file")" \
        'set -e 下 workflow_run 失败后不得执行后续步骤'
}

run_case 'register and query step' \
    case_register_and_query

run_case 'missing step query' \
    case_missing_step_query_fails

run_case 'duplicate registration' \
    case_duplicate_registration_fails

run_case 'missing function registration' \
    case_missing_function_fails

run_case 'ordered execution' \
    case_run_preserves_order

run_case 'stop after failure' \
    case_failure_stops_workflow

run_case 'unknown step execution' \
    case_unknown_step_fails

run_case 'empty workflow' \
    case_empty_workflow_fails

run_case 'before hooks preserve order' \
    case_before_hooks_preserve_order

run_case 'after hooks preserve order' \
    case_after_hooks_preserve_order

run_case 'before failure stops step' \
    case_before_failure_skips_step_and_after_hooks

run_case 'step failure skips after hooks' \
    case_step_failure_skips_after_hooks

run_case 'after failure stops workflow' \
    case_after_failure_stops_remaining_hooks_and_workflow

run_case 'hook requires registered step' \
    case_hook_registration_requires_known_step

run_case 'hook requires existing function' \
    case_hook_registration_requires_existing_function

run_case 'hook argument validation' \
    case_hook_argument_validation

run_case 'conditional step executes' \
    case_conditional_step_runs_when_condition_passes

run_case 'conditional step skips' \
    case_conditional_step_skips_when_condition_fails

run_case 'conditional registration validates functions' \
    case_conditional_registration_validates_functions

run_case 'conditional registration rejects duplicate' \
    case_conditional_registration_rejects_duplicate_step

run_case 'conditional registration argument validation' \
    case_conditional_registration_argument_validation

run_case 'unavailable condition function' \
    case_unavailable_condition_function_fails_at_runtime

run_case 'conditional skip with errexit' \
    case_conditional_skip_is_safe_with_errexit

run_case 'before failure with errexit' \
    case_before_failure_is_explicit_with_errexit

run_case 'step failure with errexit' \
    case_step_failure_is_explicit_with_errexit

run_case 'after failure with errexit' \
    case_after_failure_is_explicit_with_errexit

run_case 'workflow failure with errexit' \
    case_workflow_failure_is_explicit_with_errexit

printf \
    '%s\nPassed: %d\nFailed: %d\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All workflow unit tests passed.\n'