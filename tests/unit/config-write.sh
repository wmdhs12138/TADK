#!/data/data/com.termux/files/usr/bin/bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_ROOT="$HOME/.cache/tadk/tests/config-write.$$"
CASE_INDEX=0

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/lib/config.sh"
source "$TADK_ROOT/lib/config-write.sh"

PASSED=0
FAILED=0
CASE_ROOT=""

cleanup() {
    rm -rf "$WORK_ROOT"
}

trap cleanup EXIT HUP INT TERM

rm -rf "$WORK_ROOT"
mkdir -p "$WORK_ROOT"

new_case_root() {
    CASE_INDEX=$((CASE_INDEX + 1))
    CASE_ROOT="$WORK_ROOT/case-$CASE_INDEX"
    mkdir -p "$CASE_ROOT"
}

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

write_existing_config() {
    local root="$1"
    local module="$2"
    local variant="$3"

    mkdir -p "$root/.tadk"

    cat > "$root/.tadk/project.conf" <<CONFIG
version=1
module=$module
variant=$variant
CONFIG
}

case_write_requires_three_arguments() {
    local status=0

    tadk_config_write one two >/dev/null 2>&1 ||
        status=$?

    assert_equals '64' "$status" ||
        return 1
}

case_set_requires_three_arguments() {
    local status=0

    tadk_config_set one two >/dev/null 2>&1 ||
        status=$?

    assert_equals '64' "$status" ||
        return 1
}

case_write_creates_configuration() {
    local root config status=0

    new_case_root
    root="$CASE_ROOT"

    tadk_config_write "$root" mobile release ||
        status=$?

    assert_success "$status" ||
        return 1

    config="$(cat "$root/.tadk/project.conf")"

    assert_equals \
        $'version=1\nmodule=mobile\nvariant=release' \
        "$config" ||
        return 1

    assert_equals '1' "$TADK_CONFIG_VERSION" ||
        return 1

    assert_equals 'mobile' "$TADK_CONFIG_MODULE" ||
        return 1

    assert_equals 'release' "$TADK_CONFIG_VARIANT" ||
        return 1
}

case_write_rejects_invalid_module() {
    local root status=0

    new_case_root
    root="$CASE_ROOT"

    tadk_config_write "$root" '../app' debug \
        >/dev/null 2>&1 ||
        status=$?

    assert_equals '65' "$status" ||
        return 1

    assert_file_not_exists "$root/.tadk/project.conf" ||
        return 1
}

case_write_rejects_invalid_variant() {
    local root status=0

    new_case_root
    root="$CASE_ROOT"

    tadk_config_write "$root" app benchmark \
        >/dev/null 2>&1 ||
        status=$?

    assert_equals '65' "$status" ||
        return 1

    assert_file_not_exists "$root/.tadk/project.conf" ||
        return 1
}

case_set_module_preserves_variant() {
    local root config status=0

    new_case_root
    root="$CASE_ROOT"

    write_existing_config "$root" app release

    tadk_config_set "$root" module mobile ||
        status=$?

    assert_success "$status" ||
        return 1

    config="$(cat "$root/.tadk/project.conf")"

    assert_equals \
        $'version=1\nmodule=mobile\nvariant=release' \
        "$config" ||
        return 1
}

case_set_variant_preserves_module() {
    local root config status=0

    new_case_root
    root="$CASE_ROOT"

    write_existing_config "$root" mobile release

    tadk_config_set "$root" variant debug ||
        status=$?

    assert_success "$status" ||
        return 1

    config="$(cat "$root/.tadk/project.conf")"

    assert_equals \
        $'version=1\nmodule=mobile\nvariant=debug' \
        "$config" ||
        return 1
}

case_set_rejects_unknown_key() {
    local root before after status=0

    new_case_root
    root="$CASE_ROOT"

    write_existing_config "$root" app debug
    before="$(cat "$root/.tadk/project.conf")"

    tadk_config_set "$root" version 2 \
        >/dev/null 2>&1 ||
        status=$?

    assert_equals '64' "$status" ||
        return 1

    after="$(cat "$root/.tadk/project.conf")"

    assert_equals "$before" "$after" ||
        return 1
}

case_set_requires_existing_configuration() {
    local root status=0

    new_case_root
    root="$CASE_ROOT"

    tadk_config_set "$root" variant release \
        >/dev/null 2>&1 ||
        status=$?

    assert_equals '1' "$status" ||
        return 1

    assert_file_not_exists "$root/.tadk/project.conf" ||
        return 1
}

case_invalid_existing_config_is_not_overwritten() {
    local root before after status=0

    new_case_root
    root="$CASE_ROOT"

    mkdir -p "$root/.tadk"

    cat > "$root/.tadk/project.conf" <<'CONFIG'
version=1
module=app
variant=benchmark
CONFIG

    before="$(cat "$root/.tadk/project.conf")"

    tadk_config_set "$root" module mobile \
        >/dev/null 2>&1 ||
        status=$?

    assert_equals '65' "$status" ||
        return 1

    after="$(cat "$root/.tadk/project.conf")"

    assert_equals "$before" "$after" ||
        return 1
}

case_write_propagates_reload_failure() {
    local root status=0
    local original_definition

    new_case_root
    root="$CASE_ROOT"

    original_definition="$(declare -f tadk_config_load)"

    tadk_config_load() {
        return 65
    }

    tadk_config_write "$root" app debug \
        >/dev/null 2>&1 ||
        status=$?

    eval "$original_definition"

    assert_equals '65' "$status" ||
        return 1
}

case_write_leaves_no_temporary_file() {
    local root status=0
    local temporary_count

    new_case_root
    root="$CASE_ROOT"

    tadk_config_write "$root" app debug ||
        status=$?

    assert_success "$status" ||
        return 1

    temporary_count="$(
        find "$root/.tadk" \
            -maxdepth 1 \
            -type f \
            -name '.project.conf.tmp.*' |
        wc -l
    )"

    temporary_count="${temporary_count//[[:space:]]/}"

    assert_equals '0' "$temporary_count" ||
        return 1
}

run_case \
    'write requires three arguments' \
    case_write_requires_three_arguments

run_case \
    'set requires three arguments' \
    case_set_requires_three_arguments

run_case \
    'write creates configuration' \
    case_write_creates_configuration

run_case \
    'write rejects invalid module' \
    case_write_rejects_invalid_module

run_case \
    'write rejects invalid variant' \
    case_write_rejects_invalid_variant

run_case \
    'set module preserves variant' \
    case_set_module_preserves_variant

run_case \
    'set variant preserves module' \
    case_set_variant_preserves_module

run_case \
    'set rejects unknown key' \
    case_set_rejects_unknown_key

run_case \
    'set requires existing configuration' \
    case_set_requires_existing_configuration

run_case \
    'invalid existing config is not overwritten' \
    case_invalid_existing_config_is_not_overwritten

run_case \
    'write propagates reload failure' \
    case_write_propagates_reload_failure

run_case \
    'write leaves no temporary file' \
    case_write_leaves_no_temporary_file

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All project configuration writer unit tests passed.\n'
