#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

TADK_ROOT="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &&
        pwd
)"

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

case_requires_script() {
    local status=0

    run_bash_errexit >/dev/null 2>&1 || status=$?

    assert_equals \
        '2' \
        "$status" \
        '缺少脚本时应返回参数错误'
}

case_success_status() {
    RUN_STATUS=99

    run_bash_errexit ':'

    assert_equals \
        '0' \
        "$RUN_STATUS" \
        '成功脚本应记录退出码 0'
}

case_preserves_failure_status() {
    run_bash_errexit 'exit 37'

    assert_equals \
        '37' \
        "$RUN_STATUS" \
        '失败脚本应保留原始退出码'
}

case_enables_errexit() {
    local trace_file
    trace_file="$(mktemp)"
    trap 'rm -f "$trace_file"' RETURN

    run_bash_errexit '
        trace_file="$1"

        printf "before\n" >> "$trace_file"
        false
        printf "after\n" >> "$trace_file"
    ' "$trace_file"

    assert_equals \
        '1' \
        "$RUN_STATUS" \
        'set -e 应在命令失败时终止脚本'

    assert_equals \
        'before' \
        "$(cat "$trace_file")" \
        '失败后的命令不应执行'
}

case_passes_arguments() {
    local output_file
    output_file="$(mktemp)"
    trap 'rm -f "$output_file"' RETURN

    run_bash_errexit '
        output_file="$1"
        first="$2"
        second="$3"

        printf "%s:%s\n" \
            "$first" \
            "$second" \
            > "$output_file"
    ' "$output_file" alpha beta

    assert_equals \
        '0' \
        "$RUN_STATUS" \
        '带参数脚本应成功'

    assert_equals \
        'alpha:beta' \
        "$(cat "$output_file")" \
        'helper 应按顺序传递参数'
}

case_safe_when_caller_uses_errexit() {
    local status=0

    (
        set -e

        run_bash_errexit 'exit 29'

        assert_equals \
            '29' \
            "$RUN_STATUS" \
            '调用方启用 set -e 时仍应捕获退出码'
    ) || status=$?

    assert_equals \
        '0' \
        "$status" \
        'helper 不应触发调用方提前退出'
}

run_case \
    'requires script' \
    case_requires_script

run_case \
    'success status' \
    case_success_status

run_case \
    'preserves failure status' \
    case_preserves_failure_status

run_case \
    'enables errexit' \
    case_enables_errexit

run_case \
    'passes arguments' \
    case_passes_arguments

run_case \
    'safe with caller errexit' \
    case_safe_when_caller_uses_errexit

printf \
    '%s\nPassed: %d\nFailed: %d\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

if (( FAILED != 0 )); then
    exit 1
fi

printf '%s\n' \
    'All process helper unit tests passed.'
