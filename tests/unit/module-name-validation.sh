#!/data/data/com.termux/files/usr/bin/bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/lib/config.sh"
source "$TADK_ROOT/lib/build.sh"

PASSED=0
FAILED=0

run_case() {
    local name="$1"
    shift

    printf 'TEST %s\n' "$name"

    if "$@"; then
        PASSED=$((PASSED + 1))
        printf 'PASS %s\n\n' "$name"
    else
        FAILED=$((FAILED + 1))
        printf 'FAIL %s\n\n' "$name" >&2
    fi
}

assert_config_module_valid() {
    if (( $# != 1 )); then
        return 64
    fi

    local module="$1"
    local status=0

    _config_validate_module "$module" ||
        status=$?

    assert_success "$status"
}

assert_config_module_invalid() {
    if (( $# != 1 )); then
        return 64
    fi

    local module="$1"
    local status=0

    _config_validate_module "$module" ||
        status=$?

    assert_equals '1' "$status"
}

assert_build_module_valid() {
    if (( $# != 1 )); then
        return 64
    fi

    local module="$1"
    local status=0

    tadk_build_validate_module "$module" ||
        status=$?

    assert_success "$status"
}

assert_build_module_invalid() {
    if (( $# != 1 )); then
        return 64
    fi

    local module="$1"
    local status=0

    tadk_build_validate_module "$module" ||
        status=$?

    assert_equals '1' "$status"
}

case_config_rejects_single_dot() {
    assert_config_module_invalid '.'
}

case_config_rejects_double_dot() {
    assert_config_module_invalid '..'
}

case_build_rejects_single_dot() {
    assert_build_module_invalid '.'
}

case_build_rejects_double_dot() {
    assert_build_module_invalid '..'
}

case_config_accepts_supported_names() {
    local module

    for module in \
        app \
        mobile \
        feature_login \
        feature-login \
        feature.login \
        app2
    do
        assert_config_module_valid "$module" ||
            return 1
    done
}

case_build_accepts_supported_names() {
    local module

    for module in \
        app \
        mobile \
        feature_login \
        feature-login \
        feature.login \
        app2
    do
        assert_build_module_valid "$module" ||
            return 1
    done
}

case_validators_reject_empty_name() {
    assert_config_module_invalid '' ||
        return 1

    assert_build_module_invalid '' ||
        return 1
}

case_validators_reject_path_separator() {
    assert_config_module_invalid 'feature/login' ||
        return 1

    assert_build_module_invalid 'feature/login' ||
        return 1
}

case_validators_reject_whitespace() {
    assert_config_module_invalid 'feature login' ||
        return 1

    assert_build_module_invalid 'feature login' ||
        return 1
}

case_build_task_rejects_dot_modules() {
    local output status=0

    output="$(
        tadk_build_module_task '.' debug 2>&1
    )" || status=$?

    assert_equals '1' "$status" ||
        return 1

    assert_equals '' "$output" ||
        return 1

    status=0

    output="$(
        tadk_build_module_task '..' release 2>&1
    )" || status=$?

    assert_equals '1' "$status" ||
        return 1

    assert_equals '' "$output" ||
        return 1
}

case_build_task_accepts_normal_module() {
    local output status=0

    output="$(
        tadk_build_module_task app debug
    )" || status=$?

    assert_success "$status" ||
        return 1

    assert_equals ':app:assembleDebug' "$output"
}

case_validator_argument_status_is_preserved() {
    local config_status=0
    local build_status=0

    _config_validate_module >/dev/null 2>&1 ||
        config_status=$?

    tadk_build_validate_module >/dev/null 2>&1 ||
        build_status=$?

    assert_equals '64' "$config_status" ||
        return 1

    assert_equals '64' "$build_status"
}

run_case \
    'config rejects single dot' \
    case_config_rejects_single_dot

run_case \
    'config rejects double dot' \
    case_config_rejects_double_dot

run_case \
    'build rejects single dot' \
    case_build_rejects_single_dot

run_case \
    'build rejects double dot' \
    case_build_rejects_double_dot

run_case \
    'config accepts supported names' \
    case_config_accepts_supported_names

run_case \
    'build accepts supported names' \
    case_build_accepts_supported_names

run_case \
    'validators reject empty name' \
    case_validators_reject_empty_name

run_case \
    'validators reject path separator' \
    case_validators_reject_path_separator

run_case \
    'validators reject whitespace' \
    case_validators_reject_whitespace

run_case \
    'build task rejects dot modules' \
    case_build_task_rejects_dot_modules

run_case \
    'build task accepts normal module' \
    case_build_task_accepts_normal_module

run_case \
    'validator argument status is preserved' \
    case_validator_argument_status_is_preserved

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All module name validation unit tests passed.\n'
