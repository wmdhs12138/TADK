#!/usr/bin/env bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_ROOT="$HOME/.cache/tadk/tests/android-module.$$"

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/lib/android.sh"

PASSED=0
FAILED=0

cleanup() {
    rm -rf "$WORK_ROOT"
}

trap cleanup EXIT HUP INT TERM

rm -rf "$WORK_ROOT"
mkdir -p "$WORK_ROOT"

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

case_selects_configured_module_application_id() {
    local output status=0

    mkdir -p "$WORK_ROOT/app" "$WORK_ROOT/mobile"

    cat > "$WORK_ROOT/app/build.gradle.kts" <<'GRADLE'
android {
    namespace = "com.example.app"
    defaultConfig {
        applicationId = "com.example.app"
    }
}
GRADLE

    cat > "$WORK_ROOT/mobile/build.gradle.kts" <<'GRADLE'
android {
    namespace = "com.example.mobile"
    defaultConfig {
        applicationId = "com.example.mobile"
    }
}
GRADLE

    output="$(
        tadk_android_module_package_name \
            "$WORK_ROOT" \
            mobile
    )" || status=$?

    assert_success "$status" ||
        return 1

    assert_equals 'com.example.mobile' "$output"
}

case_prefers_application_id_over_namespace() {
    local root="$WORK_ROOT/prefer"
    local output status=0

    mkdir -p "$root/app"

    cat > "$root/app/build.gradle.kts" <<'GRADLE'
android {
    namespace = "com.example.namespace"
    defaultConfig {
        applicationId = "com.example.application"
    }
}
GRADLE

    output="$(
        tadk_android_module_package_name \
            "$root" \
            app
    )" || status=$?

    assert_success "$status" ||
        return 1

    assert_equals 'com.example.application' "$output"
}

case_falls_back_to_namespace() {
    local root="$WORK_ROOT/namespace"
    local output status=0

    mkdir -p "$root/app"

    cat > "$root/app/build.gradle" <<'GRADLE'
android {
    namespace "com.example.namespace"
}
GRADLE

    output="$(
        tadk_android_module_package_name \
            "$root" \
            app
    )" || status=$?

    assert_success "$status" ||
        return 1

    assert_equals 'com.example.namespace' "$output"
}

case_missing_module_returns_failure() {
    local status=0

    tadk_android_module_package_name \
        "$WORK_ROOT" \
        missing \
        >/dev/null 2>&1 ||
        status=$?

    assert_equals '1' "$status"
}

case_module_without_package_returns_failure() {
    local root="$WORK_ROOT/empty"
    local status=0

    mkdir -p "$root/app"

    cat > "$root/app/build.gradle.kts" <<'GRADLE'
plugins {
    id("com.android.application")
}
GRADLE

    tadk_android_module_package_name \
        "$root" \
        app \
        >/dev/null 2>&1 ||
        status=$?

    assert_equals '1' "$status"
}

run_case \
    'selects configured module applicationId' \
    case_selects_configured_module_application_id

run_case \
    'prefers applicationId over namespace' \
    case_prefers_application_id_over_namespace

run_case \
    'falls back to namespace' \
    case_falls_back_to_namespace

run_case \
    'missing module returns failure' \
    case_missing_module_returns_failure

run_case \
    'module without package returns failure' \
    case_module_without_package_returns_failure

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All Android module unit tests passed.\n'
