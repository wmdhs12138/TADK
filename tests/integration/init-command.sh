#!/data/data/com.termux/files/usr/bin/bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_ROOT="$HOME/.cache/tadk/tests/init-command.$$"
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
    local root="$1"
    local module="${2:-app}"

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

case_help_succeeds() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" init --help 2>&1
    )" || status=$?

    assert_success "$status"
    assert_contains "$output" \
        'tadk init [选项] [PROJECT_ROOT]'
    assert_contains "$output" '--force'
    assert_contains "$output" '--module MODULE'
    assert_contains "$output" '.tadk/project.conf'
}

case_unknown_option_returns_64() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" init --unknown 2>&1
    )" || status=$?

    assert_equals '64' "$status"
    assert_contains "$output" '未知参数：--unknown'
}

case_multiple_paths_return_64() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" init one two 2>&1
    )" || status=$?

    assert_equals '64' "$status"
    assert_contains "$output" \
        'init 最多接受一个项目目录参数'
}

case_missing_path_returns_1() {
    local root missing output status=0

    new_case_root
    root="$CASE_ROOT"

    missing="$root/missing"

    output="$(
        "$TADK_ROOT/bin/tadk" init "$missing" 2>&1
    )" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        "项目目录不存在：$missing"
}

case_non_project_directory_returns_1() {
    local root output status=0

    new_case_root
    root="$CASE_ROOT"

    output="$(
        "$TADK_ROOT/bin/tadk" init "$root" 2>&1
    )" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        '指定目录不在有效的 Gradle Android 项目中'
    assert_file_not_exists "$root/.tadk/project.conf"
}

case_explicit_project_root_creates_config() {
    local root output config status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app

    output="$(
        "$TADK_ROOT/bin/tadk" init "$root" 2>&1
    )" || status=$?

    assert_success "$status"
    assert_file_exists "$root/.tadk/project.conf"

    config="$(cat "$root/.tadk/project.conf")"

    assert_equals \
        $'version=1\nmodule=app\nvariant=debug' \
        "$config"

    assert_contains "$output" 'TADK Init'
    assert_contains "$output" "项目：$root"
    assert_contains "$output" '覆盖：false'
    assert_contains "$output" 'Module: app'
    assert_contains "$output" 'Variant: debug'
}

case_explicit_module_is_selected() {
    local root output config status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app

    mkdir -p "$root/mobile/src/main"
    cat > "$root/mobile/build.gradle.kts" <<'BUILD'
plugins {
    id("com.android.application")
}
BUILD

    output="$(
        "$TADK_ROOT/bin/tadk" init --module mobile "$root" 2>&1
    )" || status=$?

    assert_success "$status"
    config="$(cat "$root/.tadk/project.conf")"
    assert_contains "$config" 'module=mobile'
    assert_contains "$output" 'Module: mobile'
}

case_nested_module_is_detected() {
    local root config status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" feature/chat

    "$TADK_ROOT/bin/tadk" init "$root" >/dev/null 2>&1 ||
        status=$?

    assert_success "$status"
    config="$(cat "$root/.tadk/project.conf")"
    assert_contains "$config" 'module=feature/chat'
}

case_nested_directory_resolves_project_root() {
    local root nested output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app
    nested="$root/app/src/main"

    output="$(
        "$TADK_ROOT/bin/tadk" init "$nested" 2>&1
    )" || status=$?

    assert_success "$status"
    assert_file_exists "$root/.tadk/project.conf"
    assert_contains "$output" "项目：$root"
}

case_current_directory_resolves_project_root() {
    local root nested output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" mobile
    nested="$root/mobile/src/main"

    output="$(
        cd "$nested" &&
        "$TADK_ROOT/bin/tadk" init 2>&1
    )" || status=$?

    assert_success "$status"
    assert_file_exists "$root/.tadk/project.conf"
    assert_contains \
        "$(cat "$root/.tadk/project.conf")" \
        'module=mobile'
    assert_contains "$output" "项目：$root"
}

case_existing_config_is_protected() {
    local root original output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app

    mkdir -p "$root/.tadk"
    printf 'original=true\n' > "$root/.tadk/project.conf"
    original="$(cat "$root/.tadk/project.conf")"

    output="$(
        "$TADK_ROOT/bin/tadk" init "$root" 2>&1
    )" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        'project configuration already exists'
    assert_equals \
        "$original" \
        "$(cat "$root/.tadk/project.conf")"
}

case_force_replaces_existing_config() {
    local root output config status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app

    mkdir -p "$root/.tadk"
    printf 'obsolete=true\n' > "$root/.tadk/project.conf"

    output="$(
        "$TADK_ROOT/bin/tadk" init --force "$root" 2>&1
    )" || status=$?

    assert_success "$status"

    config="$(cat "$root/.tadk/project.conf")"

    assert_equals \
        $'version=1\nmodule=app\nvariant=debug' \
        "$config"
    assert_not_contains "$config" 'obsolete=true'
    assert_contains "$output" '覆盖：true'
}

case_force_after_path_is_accepted() {
    local root status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root" app

    mkdir -p "$root/.tadk"
    printf 'obsolete=true\n' > "$root/.tadk/project.conf"

    "$TADK_ROOT/bin/tadk" init "$root" --force \
        >/dev/null 2>&1 ||
        status=$?

    assert_success "$status"
    assert_contains \
        "$(cat "$root/.tadk/project.conf")" \
        'module=app'
}

run_case \
    'help succeeds' \
    case_help_succeeds

run_case \
    'unknown option returns 64' \
    case_unknown_option_returns_64

run_case \
    'multiple paths return 64' \
    case_multiple_paths_return_64

run_case \
    'missing path returns 1' \
    case_missing_path_returns_1

run_case \
    'non-project directory returns 1' \
    case_non_project_directory_returns_1

run_case \
    'explicit project root creates config' \
    case_explicit_project_root_creates_config

run_case \
    'explicit module is selected' \
    case_explicit_module_is_selected

run_case \
    'nested module is detected' \
    case_nested_module_is_detected

run_case \
    'nested directory resolves project root' \
    case_nested_directory_resolves_project_root

run_case \
    'current directory resolves project root' \
    case_current_directory_resolves_project_root

run_case \
    'existing config is protected' \
    case_existing_config_is_protected

run_case \
    'force replaces existing config' \
    case_force_replaces_existing_config

run_case \
    'force after path is accepted' \
    case_force_after_path_is_accepted

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All init command integration tests passed.\n'
