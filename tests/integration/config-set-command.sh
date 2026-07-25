#!/usr/bin/env bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_ROOT="$HOME/.cache/tadk/tests/config-set-command.$$"
CASE_INDEX=0
CASE_ROOT=""

source "$TADK_ROOT/tests/helpers/assertions.sh"

PASSED=0
FAILED=0

cleanup() {
    rm -rf "$WORK_ROOT"
}

trap cleanup EXIT HUP INT TERM

rm -rf "$WORK_ROOT"
mkdir -p "$WORK_ROOT"

new_case_root() {
    CASE_INDEX=$((CASE_INDEX + 1))
    CASE_ROOT="$WORK_ROOT/case-$CASE_INDEX"

    rm -rf "$CASE_ROOT"
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

create_project() {
    if (( $# != 2 )); then
        return 64
    fi

    local root="$1"
    local module="$2"

    mkdir -p "$root/$module/src/main"

    cat > "$root/gradlew" <<'GRADLEW'
#!/usr/bin/env bash
exit 0
GRADLEW

    chmod +x "$root/gradlew"

    cat > "$root/settings.gradle.kts" <<SETTINGS
rootProject.name = "Example"
include(":$module")
SETTINGS

    cat > "$root/$module/build.gradle.kts" <<'BUILD'
plugins {
    id("com.android.application")
}
BUILD

    cat > "$root/$module/src/main/AndroidManifest.xml" <<'MANIFEST'
<manifest package="com.example.app" />
MANIFEST
}

write_config() {
    if (( $# != 3 )); then
        return 64
    fi

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

case_help_lists_set_command() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" config --help 2>&1
    )" || status=$?

    assert_success "$status" ||
        return 1

    assert_contains "$output" \
        'tadk config set module MODULE [PROJECT_ROOT]' ||
        return 1

    assert_contains "$output" \
        'tadk config set variant debug|release [PROJECT_ROOT]' ||
        return 1
}

case_set_requires_key_and_value() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" config set 2>&1
    )" || status=$?

    assert_equals '64' "$status" ||
        return 1

    assert_contains "$output" \
        'config set 需要配置键和值' ||
        return 1
}

case_set_rejects_unknown_key() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config set version 2 2>&1
    )" || status=$?

    assert_equals '64' "$status" ||
        return 1

    assert_contains "$output" \
        '不支持的配置键：version' ||
        return 1
}

case_set_rejects_too_many_arguments() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config set module app one two 2>&1
    )" || status=$?

    assert_equals '64' "$status" ||
        return 1

    assert_contains "$output" \
        'config set 最多接受配置键、值和一个项目目录参数' ||
        return 1
}

case_set_module_updates_configuration() {
    local root output config status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app
    mkdir -p "$root/mobile"
    write_config "$root" app release

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config set module mobile "$root" 2>&1
    )" || status=$?

    assert_success "$status" ||
        return 1

    config="$(cat "$root/.tadk/project.conf")"

    assert_equals \
        $'version=1\nmodule=mobile\nvariant=release' \
        "$config" ||
        return 1

    assert_contains "$output" \
        "项目配置已更新：$root/.tadk/project.conf" ||
        return 1

    assert_contains "$output" \
        'Module: mobile' ||
        return 1

    assert_contains "$output" \
        'Variant: release' ||
        return 1
}

case_set_variant_updates_configuration() {
    local root output config status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app
    write_config "$root" app debug

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config set variant release "$root" 2>&1
    )" || status=$?

    assert_success "$status" ||
        return 1

    config="$(cat "$root/.tadk/project.conf")"

    assert_equals \
        $'version=1\nmodule=app\nvariant=release' \
        "$config" ||
        return 1

    assert_contains "$output" \
        'Module: app' ||
        return 1

    assert_contains "$output" \
        'Variant: release' ||
        return 1
}

case_set_uses_current_directory() {
    local root nested config status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app
    write_config "$root" app debug

    nested="$root/app/src/main"

    (
        cd "$nested" &&
        "$TADK_ROOT/bin/tadk" \
            config set variant release
    ) >/dev/null 2>&1 || status=$?

    assert_success "$status" ||
        return 1

    config="$(cat "$root/.tadk/project.conf")"

    assert_equals \
        $'version=1\nmodule=app\nvariant=release' \
        "$config" ||
        return 1
}

case_set_resolves_nested_path() {
    local root nested config status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app
    write_config "$root" app release

    nested="$root/app/src/main"

    "$TADK_ROOT/bin/tadk" \
        config set variant debug "$nested" \
        >/dev/null 2>&1 ||
        status=$?

    assert_success "$status" ||
        return 1

    config="$(cat "$root/.tadk/project.conf")"

    assert_equals \
        $'version=1\nmodule=app\nvariant=debug' \
        "$config" ||
        return 1
}

case_set_missing_config_returns_1() {
    local root output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config set variant release "$root" 2>&1
    )" || status=$?

    assert_equals '1' "$status" ||
        return 1

    assert_contains "$output" \
        'project configuration does not exist' ||
        return 1

    assert_file_not_exists "$root/.tadk/project.conf" ||
        return 1
}

case_set_invalid_existing_config_preserves_65() {
    local root before after output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app
    mkdir -p "$root/.tadk"

    cat > "$root/.tadk/project.conf" <<'CONFIG'
version=1
module=app
variant=benchmark
CONFIG

    before="$(cat "$root/.tadk/project.conf")"

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config set module mobile "$root" 2>&1
    )" || status=$?

    assert_equals '65' "$status" ||
        return 1

    after="$(cat "$root/.tadk/project.conf")"

    assert_equals "$before" "$after" ||
        return 1

    assert_contains "$output" \
        "invalid variant 'benchmark'" ||
        return 1
}

case_set_rejects_invalid_module_value() {
    local root before after status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app
    write_config "$root" app debug

    before="$(cat "$root/.tadk/project.conf")"

    "$TADK_ROOT/bin/tadk" \
        config set module '../app' "$root" \
        >/dev/null 2>&1 ||
        status=$?

    assert_equals '65' "$status" ||
        return 1

    after="$(cat "$root/.tadk/project.conf")"

    assert_equals "$before" "$after" ||
        return 1
}

case_set_rejects_invalid_variant_value() {
    local root before after status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app
    write_config "$root" app debug

    before="$(cat "$root/.tadk/project.conf")"

    "$TADK_ROOT/bin/tadk" \
        config set variant benchmark "$root" \
        >/dev/null 2>&1 ||
        status=$?

    assert_equals '65' "$status" ||
        return 1

    after="$(cat "$root/.tadk/project.conf")"

    assert_equals "$before" "$after" ||
        return 1
}

case_show_still_works() {
    local root output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app
    write_config "$root" app debug

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config show "$root" 2>&1
    )" || status=$?

    assert_success "$status" ||
        return 1

    assert_contains "$output" \
        '模块：app' ||
        return 1

    assert_contains "$output" \
        '变体：debug' ||
        return 1
}

case_validate_still_works() {
    local root output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app
    write_config "$root" app release

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config validate "$root" 2>&1
    )" || status=$?

    assert_success "$status" ||
        return 1

    assert_contains "$output" \
        'Module: app' ||
        return 1

    assert_contains "$output" \
        'Variant: release' ||
        return 1
}

run_case \
    'help lists set command' \
    case_help_lists_set_command

run_case \
    'set requires key and value' \
    case_set_requires_key_and_value

run_case \
    'set rejects unknown key' \
    case_set_rejects_unknown_key

run_case \
    'set rejects too many arguments' \
    case_set_rejects_too_many_arguments

run_case \
    'set module updates configuration' \
    case_set_module_updates_configuration

run_case \
    'set variant updates configuration' \
    case_set_variant_updates_configuration

run_case \
    'set uses current directory' \
    case_set_uses_current_directory

run_case \
    'set resolves nested path' \
    case_set_resolves_nested_path

run_case \
    'set missing config returns 1' \
    case_set_missing_config_returns_1

run_case \
    'set invalid existing config preserves 65' \
    case_set_invalid_existing_config_preserves_65

run_case \
    'set rejects invalid module value' \
    case_set_rejects_invalid_module_value

run_case \
    'set rejects invalid variant value' \
    case_set_rejects_invalid_variant_value

run_case \
    'show still works' \
    case_show_still_works

run_case \
    'validate still works' \
    case_validate_still_works

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All config set command integration tests passed.\n'
