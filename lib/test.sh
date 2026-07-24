#!/data/data/com.termux/files/usr/bin/bash

# TADK test runner library.
#
# This file is intended to be sourced by commands and tests.
# Do not enable set -e here because it would affect the caller.
#
# Public API:
#   test_run_unit TADK_ROOT
#   test_run_smoke TADK_ROOT
#   test_run_integration TADK_ROOT
#   test_run_all TADK_ROOT
#
# Exit codes:
#   0   all requested tests passed
#   1   a test suite failed or its runner is unavailable
#   64  invalid arguments

if [[ -n "${TADK_TEST_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_TEST_SH_LOADED=1

_test_error() {
    if declare -F tadk_error >/dev/null 2>&1; then
        tadk_error "$1"
    else
        printf 'test: %s\n' "$1" >&2
    fi
}

_test_info() {
    if declare -F tadk_info >/dev/null 2>&1; then
        tadk_info "$1"
    else
        printf '%s\n' "$1"
    fi
}

_test_success() {
    if declare -F tadk_success >/dev/null 2>&1; then
        tadk_success "$1"
    else
        printf '✓ %s\n' "$1"
    fi
}

_test_require_root() {
    if (( $# != 1 )); then
        _test_error \
            'internal error: _test_require_root requires TADK_ROOT'
        return 64
    fi

    local tadk_root="$1"

    if [[ -z "$tadk_root" ]]; then
        _test_error 'TADK_ROOT must not be empty'
        return 64
    fi

    if [[ ! -d "$tadk_root" ]]; then
        _test_error "TADK root does not exist: $tadk_root"
        return 1
    fi
}

_test_require_runner() {
    if (( $# != 1 )); then
        _test_error \
            'internal error: _test_require_runner requires a path'
        return 64
    fi

    local runner="$1"

    if [[ ! -f "$runner" ]]; then
        _test_error "test runner does not exist: $runner"
        return 1
    fi

    if [[ ! -r "$runner" ]]; then
        _test_error "test runner is not readable: $runner"
        return 1
    fi
}

_test_run_runner() {
    if (( $# != 2 )); then
        _test_error \
            'internal error: _test_run_runner requires NAME RUNNER'
        return 64
    fi

    local suite_name="$1"
    local runner="$2"
    local exit_code

    _test_require_runner "$runner" || return $?

    _test_info "Running $suite_name tests..."

    bash "$runner"
    exit_code=$?

    if (( exit_code != 0 )); then
        _test_error "$suite_name tests failed"
        return "$exit_code"
    fi

    _test_success "$suite_name tests passed"
}

test_run_unit() {
    if (( $# != 1 )); then
        _test_error 'usage: test_run_unit TADK_ROOT'
        return 64
    fi

    local tadk_root="$1"

    _test_require_root "$tadk_root" || return $?

    _test_run_runner \
        unit \
        "$tadk_root/tests/unit/run.sh"
}

test_run_smoke() {
    if (( $# != 1 )); then
        _test_error 'usage: test_run_smoke TADK_ROOT'
        return 64
    fi

    local tadk_root="$1"

    _test_require_root "$tadk_root" || return $?

    _test_run_runner \
        smoke \
        "$tadk_root/tests/smoke.sh"
}

test_run_integration() {
    if (( $# != 1 )); then
        _test_error 'usage: test_run_integration TADK_ROOT'
        return 64
    fi

    local tadk_root="$1"

    _test_require_root "$tadk_root" || return $?

    _test_run_runner \
        integration \
        "$tadk_root/tests/integration/run.sh"
}

test_run_all() {
    if (( $# != 1 )); then
        _test_error 'usage: test_run_all TADK_ROOT'
        return 64
    fi

    local tadk_root="$1"
    local exit_code

    _test_require_root "$tadk_root" || return $?

    test_run_unit "$tadk_root"
    exit_code=$?

    if (( exit_code != 0 )); then
        return "$exit_code"
    fi

    printf '\n'

    test_run_smoke "$tadk_root"
    exit_code=$?

    if (( exit_code != 0 )); then
        return "$exit_code"
    fi

    printf '\n'

    test_run_integration "$tadk_root"
    exit_code=$?

    if (( exit_code != 0 )); then
        return "$exit_code"
    fi

    printf '\n'
    _test_success 'All tests passed'
}
