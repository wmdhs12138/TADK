#!/data/data/com.termux/files/usr/bin/bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/lib/config.sh"

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

create_config() {
    local root="$1"
    local content="$2"

    mkdir -p "$root/.tadk"
    printf '%s' "$content" > "$root/.tadk/project.conf"
}

case_requires_one_argument() {
    local output status=0

    output="$(tadk_config_load 2>&1)" || status=$?

    assert_equals '64' "$status"
    assert_contains "$output" \
        'usage: tadk_config_load PROJECT_ROOT'
}

case_missing_config_returns_1() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    output="$(tadk_config_load "$root" 2>&1)" ||
        status=$?

    assert_equals '1' "$status"
    assert_equals '' "$output"
    assert_equals '' "$TADK_CONFIG_VERSION"
    assert_equals '' "$TADK_CONFIG_MODULE"
    assert_equals '' "$TADK_CONFIG_VARIANT"
}

case_loads_valid_config() {
    local root status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_config \
        "$root" \
        $'version=1\nmodule=app\nvariant=debug\n'

    tadk_config_load "$root" || status=$?

    assert_success "$status"
    assert_equals '1' "$TADK_CONFIG_VERSION"
    assert_equals 'app' "$TADK_CONFIG_MODULE"
    assert_equals 'debug' "$TADK_CONFIG_VARIANT"
}

case_accepts_comments_and_blank_lines() {
    local root status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_config \
        "$root" \
        $'# TADK project\n\nversion=1\nmodule=mobile\nvariant=release\n'

    tadk_config_load "$root" || status=$?

    assert_success "$status"
    assert_equals 'mobile' "$TADK_CONFIG_MODULE"
    assert_equals 'release' "$TADK_CONFIG_VARIANT"
}

case_accepts_nested_module() {
    local root status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_config \
        "$root" \
        $'version=1\nmodule=feature/chat\nvariant=debug\n'

    tadk_config_load "$root" || status=$?

    assert_success "$status"
    assert_equals 'feature/chat' "$TADK_CONFIG_MODULE"
}

case_rejects_shell_syntax_without_execution() {
    local root marker output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    marker="$root/executed"

    create_config \
        "$root" \
        "version=\$(touch $marker)"$'\nmodule=app\nvariant=debug\n'

    output="$(tadk_config_load "$root" 2>&1)" ||
        status=$?

    assert_equals '65' "$status"
    assert_file_not_exists "$marker"
    assert_contains "$output" \
        'unsupported configuration version'
}

case_rejects_unknown_key() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_config \
        "$root" \
        $'version=1\nmodule=app\nvariant=debug\nextra=true\n'

    output="$(tadk_config_load "$root" 2>&1)" ||
        status=$?

    assert_equals '65' "$status"
    assert_contains "$output" "unknown key 'extra'"
}

case_rejects_duplicate_key() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_config \
        "$root" \
        $'version=1\nmodule=app\nmodule=mobile\nvariant=debug\n'

    output="$(tadk_config_load "$root" 2>&1)" ||
        status=$?

    assert_equals '65' "$status"
    assert_contains "$output" "duplicate key 'module'"
}

case_rejects_missing_required_key() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_config \
        "$root" \
        $'version=1\nmodule=app\n'

    output="$(tadk_config_load "$root" 2>&1)" ||
        status=$?

    assert_equals '65' "$status"
    assert_contains "$output" \
        "missing required key 'variant'"
}

case_rejects_unsupported_version() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_config \
        "$root" \
        $'version=2\nmodule=app\nvariant=debug\n'

    output="$(tadk_config_load "$root" 2>&1)" ||
        status=$?

    assert_equals '65' "$status"
    assert_contains "$output" \
        "unsupported configuration version '2'"
}

case_rejects_invalid_module() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_config \
        "$root" \
        $'version=1\nmodule=../app\nvariant=debug\n'

    output="$(tadk_config_load "$root" 2>&1)" ||
        status=$?

    assert_equals '65' "$status"
    assert_contains "$output" "invalid module '../app'"
}

case_rejects_invalid_variant() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_config \
        "$root" \
        $'version=1\nmodule=app\nvariant=benchmark\n'

    output="$(tadk_config_load "$root" 2>&1)" ||
        status=$?

    assert_equals '65' "$status"
    assert_contains "$output" \
        "invalid variant 'benchmark'"
}

case_invalid_config_returns_65_directly() {
    local root status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_config \
        "$root" \
        $'version=1\nmodule=app\nvariant=benchmark\n'

    tadk_config_load "$root" >/dev/null 2>&1 ||
        status=$?

    assert_equals '65' "$status"
    assert_equals '' "$TADK_CONFIG_VERSION"
    assert_equals '' "$TADK_CONFIG_MODULE"
    assert_equals '' "$TADK_CONFIG_VARIANT"
}

case_invalid_config_survives_errexit_caller() {
    local root status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_config \
        "$root" \
        $'version=1\nmodule=app\nvariant=benchmark\n'

    (
        set -Eeuo pipefail

        source "$TADK_ROOT/lib/config.sh"

        if tadk_config_load "$root" >/dev/null 2>&1; then
            exit 0
        else
            exit $?
        fi
    ) || status=$?

    assert_equals '65' "$status"
}

case_failure_clears_previous_values() {
    local valid_root invalid_root status=0

    valid_root="$(mktemp -d)"
    invalid_root="$(mktemp -d)"
    trap 'rm -rf "$valid_root" "$invalid_root"' RETURN

    create_config \
        "$valid_root" \
        $'version=1\nmodule=app\nvariant=debug\n'

    tadk_config_load "$valid_root"

    create_config \
        "$invalid_root" \
        $'version=1\nmodule=../bad\nvariant=debug\n'

    tadk_config_load "$invalid_root" >/dev/null 2>&1 ||
        status=$?

    assert_equals '65' "$status"
    assert_equals '' "$TADK_CONFIG_VERSION"
    assert_equals '' "$TADK_CONFIG_MODULE"
    assert_equals '' "$TADK_CONFIG_VARIANT"
}

run_case \
    'requires one argument' \
    case_requires_one_argument

run_case \
    'missing config returns 1' \
    case_missing_config_returns_1

run_case \
    'loads valid config' \
    case_loads_valid_config

run_case \
    'accepts comments and blank lines' \
    case_accepts_comments_and_blank_lines

run_case \
    'accepts nested module' \
    case_accepts_nested_module

run_case \
    'rejects shell syntax without execution' \
    case_rejects_shell_syntax_without_execution

run_case \
    'rejects unknown key' \
    case_rejects_unknown_key

run_case \
    'rejects duplicate key' \
    case_rejects_duplicate_key

run_case \
    'rejects missing required key' \
    case_rejects_missing_required_key

run_case \
    'rejects unsupported version' \
    case_rejects_unsupported_version

run_case \
    'rejects invalid module' \
    case_rejects_invalid_module

run_case \
    'rejects invalid variant' \
    case_rejects_invalid_variant

run_case \
    'invalid config returns 65 directly' \
    case_invalid_config_returns_65_directly

run_case \
    'invalid config survives errexit caller' \
    case_invalid_config_survives_errexit_caller

run_case \
    'failure clears previous values' \
    case_failure_clears_previous_values

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All project configuration unit tests passed.\n'
