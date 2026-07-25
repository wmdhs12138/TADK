#!/usr/bin/env bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/lib/init.sh"

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

create_project_root() {
    local root="$1"

    mkdir -p "$root"

    cat > "$root/gradlew" <<'GRADLEW'
#!/usr/bin/env bash
exit 0
GRADLEW

    chmod +x "$root/gradlew"

    cat > "$root/settings.gradle.kts" <<'SETTINGS'
rootProject.name = "Example"
include(":app")
SETTINGS
}

create_module() {
    local root="$1"
    local module="$2"

    mkdir -p "$root/$module"

cat > "$root/$module/build.gradle.kts" <<'BUILD'
plugins {
    id("com.android.application")
}
BUILD
}

create_library_module() {
    local root="$1"
    local module="$2"

    mkdir -p "$root/$module"

    cat > "$root/$module/build.gradle.kts" <<'BUILD'
plugins {
    id("com.android.library")
}
BUILD
}

case_requires_two_arguments() {
    local output status=0

    output="$(tadk_init_project 2>&1)" || status=$?

    assert_equals '64' "$status"
    assert_contains "$output" \
        'usage: tadk_init_project PROJECT_ROOT FORCE'
}

case_rejects_invalid_force_value() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_project_root "$root"
    create_module "$root" app

    output="$(tadk_init_project "$root" yes 2>&1)" ||
        status=$?

    assert_equals '64' "$status"
    assert_contains "$output" 'FORCE must be true or false'
    assert_file_not_exists "$root/.tadk/project.conf"
}

case_rejects_non_project_directory() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    output="$(tadk_init_project "$root" false 2>&1)" ||
        status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        'not a valid Gradle Android project root'
    assert_file_not_exists "$root/.tadk/project.conf"
}

case_prefers_app_module() {
    local root output config status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_project_root "$root"
    create_module "$root" app
    create_module "$root" feature

    output="$(tadk_init_project "$root" false 2>&1)" ||
        status=$?

    assert_success "$status"
    assert_file_exists "$root/.tadk/project.conf"

    config="$(cat "$root/.tadk/project.conf")"

    assert_equals \
        $'version=1\nmodule=app\nvariant=debug' \
        "$config"

    assert_contains "$output" 'Module: app'
    assert_contains "$output" 'Variant: debug'
}

case_selects_only_direct_module() {
    local root config status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_project_root "$root"
    create_module "$root" mobile

    tadk_init_project "$root" false >/dev/null 2>&1 ||
        status=$?

    assert_success "$status"

    config="$(cat "$root/.tadk/project.conf")"

    assert_contains "$config" 'module=mobile'
}

case_selects_explicit_module() {
    local root config status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_project_root "$root"
    create_module "$root" app
    create_module "$root" mobile

    tadk_init_project "$root" false mobile >/dev/null 2>&1 ||
        status=$?

    assert_success "$status"

    config="$(cat "$root/.tadk/project.conf")"

    assert_contains "$config" 'module=mobile'
}

case_detects_nested_module() {
    local root config status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_project_root "$root"
    create_module "$root" feature/chat

    tadk_init_project "$root" false >/dev/null 2>&1 ||
        status=$?

    assert_success "$status"

    config="$(cat "$root/.tadk/project.conf")"

    assert_contains "$config" 'module=feature/chat'
}

case_rejects_explicit_library_module() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_project_root "$root"
    create_library_module "$root" common

    output="$(
        tadk_init_project "$root" false common 2>&1
    )" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        'module is not an Android application module'
    assert_file_not_exists "$root/.tadk/project.conf"
}

case_rejects_ambiguous_modules() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_project_root "$root"
    create_module "$root" mobile
    create_module "$root" wearable

    output="$(tadk_init_project "$root" false 2>&1)" ||
        status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        'automatic selection is ambiguous'
    assert_contains "$output" 'mobile'
    assert_contains "$output" 'wearable'
    assert_file_not_exists "$root/.tadk/project.conf"
}

case_refuses_existing_config_without_force() {
    local root original output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_project_root "$root"
    create_module "$root" app

    mkdir -p "$root/.tadk"
    printf 'original\n' > "$root/.tadk/project.conf"
    original="$(cat "$root/.tadk/project.conf")"

    output="$(tadk_init_project "$root" false 2>&1)" ||
        status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        'project configuration already exists'
    assert_equals \
        "$original" \
        "$(cat "$root/.tadk/project.conf")"
}

case_force_replaces_existing_config() {
    local root config status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_project_root "$root"
    create_module "$root" app

    mkdir -p "$root/.tadk"
    printf 'obsolete=true\n' > "$root/.tadk/project.conf"

    tadk_init_project "$root" true >/dev/null 2>&1 ||
        status=$?

    assert_success "$status"

    config="$(cat "$root/.tadk/project.conf")"

    assert_equals \
        $'version=1\nmodule=app\nvariant=debug' \
        "$config"
    assert_not_contains "$config" 'obsolete=true'
}

run_case \
    'requires two arguments' \
    case_requires_two_arguments

run_case \
    'rejects invalid force value' \
    case_rejects_invalid_force_value

run_case \
    'rejects non-project directory' \
    case_rejects_non_project_directory

run_case \
    'prefers app module' \
    case_prefers_app_module

run_case \
    'selects only direct module' \
    case_selects_only_direct_module

run_case \
    'selects explicit module' \
    case_selects_explicit_module

run_case \
    'detects nested module' \
    case_detects_nested_module

run_case \
    'rejects explicit library module' \
    case_rejects_explicit_library_module

run_case \
    'rejects ambiguous modules' \
    case_rejects_ambiguous_modules

run_case \
    'refuses existing config without force' \
    case_refuses_existing_config_without_force

run_case \
    'force replaces existing config' \
    case_force_replaces_existing_config

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All init configuration unit tests passed.\n'
