#!/data/data/com.termux/files/usr/bin/bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_ROOT="$HOME/.cache/tadk/tests/config-command.$$"
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

case_help_succeeds() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" config --help 2>&1
    )" || status=$?

    assert_success "$status" ||
        return 1

    assert_contains "$output" \
        'tadk config show [PROJECT_ROOT]' ||
        return 1

    assert_contains "$output" \
        'tadk config validate [PROJECT_ROOT]' ||
        return 1
}

case_missing_action_returns_64() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" config 2>&1
    )" || status=$?

    assert_equals '64' "$status" ||
        return 1

    assert_contains "$output" \
        '缺少 config 子命令' ||
        return 1
}

case_unknown_action_returns_64() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" config remove 2>&1
    )" || status=$?

    assert_equals '64' "$status" ||
        return 1

    assert_contains "$output" \
        '未知 config 子命令：remove' ||
        return 1
}

case_multiple_actions_return_64() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config show validate 2>&1
    )" || status=$?

    assert_equals '64' "$status" ||
        return 1

    assert_contains "$output" \
        'config 只能指定一个子命令' ||
        return 1
}

case_multiple_paths_return_64() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config show one two 2>&1
    )" || status=$?

    assert_equals '64' "$status" ||
        return 1

    assert_contains "$output" \
        'config 最多接受一个项目目录参数' ||
        return 1
}

case_missing_path_returns_1() {
    local root missing output status=0

    new_case_root
    root="$CASE_ROOT"
    missing="$root/missing"

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config show "$missing" 2>&1
    )" || status=$?

    assert_equals '1' "$status" ||
        return 1

    assert_contains "$output" \
        "项目目录不存在：$missing" ||
        return 1
}

case_non_project_returns_1() {
    local root output status=0

    new_case_root
    root="$CASE_ROOT"

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config validate "$root" 2>&1
    )" || status=$?

    assert_equals '1' "$status" ||
        return 1

    assert_contains "$output" \
        '指定目录不在有效的 Gradle Android 项目中' ||
        return 1
}

case_show_displays_configuration() {
    local root output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" mobile
    write_config "$root" mobile release

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config show "$root" 2>&1
    )" || status=$?

    assert_success "$status" ||
        return 1

    assert_contains "$output" \
        'TADK Project Config' ||
        return 1

    assert_contains "$output" \
        "项目：$root" ||
        return 1

    assert_contains "$output" \
        "配置：$root/.tadk/project.conf" ||
        return 1

    assert_contains "$output" \
        '版本：1' ||
        return 1

    assert_contains "$output" \
        '模块：mobile' ||
        return 1

    assert_contains "$output" \
        '变体：release' ||
        return 1
}

case_show_resolves_nested_directory() {
    local root nested output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app
    write_config "$root" app debug

    nested="$root/app/src/main"

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config show "$nested" 2>&1
    )" || status=$?

    assert_success "$status" ||
        return 1

    assert_contains "$output" \
        "项目：$root" ||
        return 1
}

case_show_uses_current_directory() {
    local root nested output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app
    write_config "$root" app debug

    nested="$root/app/src/main"

    output="$(
        cd "$nested" &&
        "$TADK_ROOT/bin/tadk" config show 2>&1
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

case_validate_succeeds() {
    local root output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" mobile
    write_config "$root" mobile release

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config validate "$root" 2>&1
    )" || status=$?

    assert_success "$status" ||
        return 1

    assert_contains "$output" \
        "项目配置有效：$root/.tadk/project.conf" ||
        return 1

    assert_contains "$output" \
        'Module: mobile' ||
        return 1

    assert_contains "$output" \
        'Variant: release' ||
        return 1
}

case_missing_config_returns_1() {
    local root output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config validate "$root" 2>&1
    )" || status=$?

    assert_equals '1' "$status" ||
        return 1

    assert_contains "$output" \
        "项目配置不存在：$root/.tadk/project.conf" ||
        return 1
}

case_invalid_config_preserves_65() {
    local root output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app

    mkdir -p "$root/.tadk"

    cat > "$root/.tadk/project.conf" <<'CONFIG'
version=1
module=app
variant=benchmark
CONFIG

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config validate "$root" 2>&1
    )" || status=$?

    assert_equals '65' "$status" ||
        return 1

    assert_contains "$output" \
        "invalid variant 'benchmark'" ||
        return 1
}

case_unknown_option_returns_64() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" \
            config show --unknown 2>&1
    )" || status=$?

    assert_equals '64' "$status" ||
        return 1

    assert_contains "$output" \
        '未知参数：--unknown' ||
        return 1
}

run_case \
    'help succeeds' \
    case_help_succeeds

run_case \
    'missing action returns 64' \
    case_missing_action_returns_64

run_case \
    'unknown action returns 64' \
    case_unknown_action_returns_64

run_case \
    'multiple actions return 64' \
    case_multiple_actions_return_64

run_case \
    'multiple paths return 64' \
    case_multiple_paths_return_64

run_case \
    'missing path returns 1' \
    case_missing_path_returns_1

run_case \
    'non-project returns 1' \
    case_non_project_returns_1

run_case \
    'show displays configuration' \
    case_show_displays_configuration

run_case \
    'show resolves nested directory' \
    case_show_resolves_nested_directory

run_case \
    'show uses current directory' \
    case_show_uses_current_directory

run_case \
    'validate succeeds' \
    case_validate_succeeds

run_case \
    'missing config returns 1' \
    case_missing_config_returns_1

run_case \
    'invalid config preserves 65' \
    case_invalid_config_preserves_65

run_case \
    'unknown option returns 64' \
    case_unknown_option_returns_64

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All config command integration tests passed.\n'
