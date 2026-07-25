#!/data/data/com.termux/files/usr/bin/bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_ROOT="$HOME/.cache/tadk/tests/module-build.$$"
CASE_INDEX=0
CASE_ROOT=""

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/apk.sh"
source "$TADK_ROOT/lib/build.sh"

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

create_apk() {
    local root="$1"
    local module="$2"
    local build_type="$3"
    local name="$4"

    mkdir -p \
        "$root/$module/build/outputs/apk/$build_type"

    printf 'apk\n' > \
        "$root/$module/build/outputs/apk/$build_type/$name"
}

case_builds_debug_module_task() {
    local output status=0

    output="$(tadk_build_module_task app debug)" ||
        status=$?

    assert_success "$status"
    assert_equals ':app:assembleDebug' "$output"
}

case_builds_release_module_task() {
    local output status=0

    output="$(tadk_build_module_task mobile release)" ||
        status=$?

    assert_success "$status"
    assert_equals ':mobile:assembleRelease' "$output"
}

case_builds_nested_module_task() {
    local output status=0

    output="$(tadk_build_module_task feature/chat debug)" ||
        status=$?

    assert_success "$status"
    assert_equals ':feature:chat:assembleDebug' "$output"
}

case_rejects_invalid_module_task() {
    local status=0

    tadk_build_module_task '../app' debug \
        >/dev/null 2>&1 ||
        status=$?

    assert_equals '1' "$status"
}

case_rejects_invalid_build_type() {
    local status=0

    tadk_build_module_task app benchmark \
        >/dev/null 2>&1 ||
        status=$?

    assert_equals '1' "$status"
}

case_finds_apk_only_in_requested_module() {
    local root selected status=0

    new_case_root
    root="$CASE_ROOT"

    create_apk "$root" app debug app-debug.apk
    create_apk "$root" demo debug demo-debug.apk

    touch \
        "$root/demo/build/outputs/apk/debug/demo-debug.apk"

    selected="$(
        tadk_find_latest_module_apk \
            "$root" \
            app \
            debug
    )" || status=$?

    assert_success "$status"
    assert_equals \
        "$root/app/build/outputs/apk/debug/app-debug.apk" \
        "$selected"
}

case_finds_requested_release_apk() {
    local root selected status=0

    new_case_root
    root="$CASE_ROOT"

    create_apk "$root" app debug app-debug.apk
    create_apk "$root" app release app-release.apk

    selected="$(
        tadk_find_latest_module_apk \
            "$root" \
            app \
            release
    )" || status=$?

    assert_success "$status"
    assert_equals \
        "$root/app/build/outputs/apk/release/app-release.apk" \
        "$selected"
}

case_ignores_android_test_and_unaligned_apks() {
    local root selected status=0

    new_case_root
    root="$CASE_ROOT"

    create_apk "$root" app debug app-debug.apk
    create_apk "$root" app debug app-debug-androidTest.apk
    create_apk "$root" app debug app-debug-unaligned.apk

    touch \
        "$root/app/build/outputs/apk/debug/app-debug-androidTest.apk"
    touch \
        "$root/app/build/outputs/apk/debug/app-debug-unaligned.apk"

    selected="$(
        tadk_find_latest_module_apk \
            "$root" \
            app \
            debug
    )" || status=$?

    assert_success "$status"
    assert_equals \
        "$root/app/build/outputs/apk/debug/app-debug.apk" \
        "$selected"
}

case_missing_module_returns_failure() {
    local root status=0

    new_case_root
    root="$CASE_ROOT"

    mkdir -p "$root"

    tadk_find_latest_module_apk \
        "$root" \
        app \
        debug \
        >/dev/null 2>&1 ||
        status=$?

    assert_equals '1' "$status"
}

case_missing_apk_returns_failure() {
    local root status=0

    new_case_root
    root="$CASE_ROOT"

    mkdir -p "$root/app"

    tadk_find_latest_module_apk \
        "$root" \
        app \
        debug \
        >/dev/null 2>&1 ||
        status=$?

    assert_equals '1' "$status"
}

case_resolve_module_rejects_other_module_path() {
    local root requested status=0

    new_case_root
    root="$CASE_ROOT"

    create_apk "$root" app debug app-debug.apk
    create_apk "$root" demo debug demo-debug.apk

    requested="$root/demo/build/outputs/apk/debug/demo-debug.apk"

    tadk_apk_resolve_module \
        "$root" \
        app \
        debug \
        "$requested" \
        >/dev/null 2>&1 ||
        status=$?

    assert_equals '1' "$status"
}

run_case \
    'builds debug module task' \
    case_builds_debug_module_task

run_case \
    'builds release module task' \
    case_builds_release_module_task

run_case \
    'builds nested module task' \
    case_builds_nested_module_task

run_case \
    'rejects invalid module task' \
    case_rejects_invalid_module_task

run_case \
    'rejects invalid build type' \
    case_rejects_invalid_build_type

run_case \
    'finds APK only in requested module' \
    case_finds_apk_only_in_requested_module

run_case \
    'finds requested release APK' \
    case_finds_requested_release_apk

run_case \
    'ignores test and unaligned APKs' \
    case_ignores_android_test_and_unaligned_apks

run_case \
    'missing module returns failure' \
    case_missing_module_returns_failure

run_case \
    'missing APK returns failure' \
    case_missing_apk_returns_failure

run_case \
    'resolve rejects another module path' \
    case_resolve_module_rejects_other_module_path

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All module build unit tests passed.\n'
