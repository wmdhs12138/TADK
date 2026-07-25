#!/data/data/com.termux/files/usr/bin/bash

# TADK environment doctor library.
#
# This file is intended to be sourced by commands and tests.
# Do not enable set -e here because it would affect the caller.
#
# Public API:
#   doctor_run PROJECT_ROOT
#
# Exit codes:
#   0   no hard failures were found
#   1   one or more hard failures were found
#   64  invalid arguments

if [[ -n "${TADK_DOCTOR_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_DOCTOR_SH_LOADED=1

DOCTOR_PASSED=0
DOCTOR_WARNINGS=0
DOCTOR_FAILED=0

doctor_command_path() {
    if (( $# != 1 )); then
        return 64
    fi

    command -v "$1" 2>/dev/null
}

doctor_java_version() {
    java -version 2>&1 | head -n 1
}

doctor_adb_devices() {
    adb devices 2>/dev/null
}

_doctor_reset() {
    DOCTOR_PASSED=0
    DOCTOR_WARNINGS=0
    DOCTOR_FAILED=0
}

_doctor_pass() {
    DOCTOR_PASSED=$((DOCTOR_PASSED + 1))
    printf 'PASS  %s\n' "$1"
}

_doctor_warn() {
    DOCTOR_WARNINGS=$((DOCTOR_WARNINGS + 1))
    printf 'WARN  %s\n' "$1"
}

_doctor_fail() {
    DOCTOR_FAILED=$((DOCTOR_FAILED + 1))
    printf 'FAIL  %s\n' "$1"
}

_doctor_check_termux() {
    if [[ "${PREFIX:-}" == *com.termux* ]]; then
        _doctor_pass "Termux environment: ${PREFIX}"
    else
        _doctor_warn 'Termux environment was not detected'
    fi
}

_doctor_check_bash() {
    local bash_path

    bash_path="$(doctor_command_path bash)" || true

    if [[ -n "$bash_path" ]]; then
        _doctor_pass "Bash found: $bash_path"
    else
        _doctor_fail 'Bash was not found in PATH'
    fi
}

_doctor_check_java() {
    local java_path java_version

    java_path="$(doctor_command_path java)" || true

    if [[ -z "$java_path" ]]; then
        _doctor_fail 'Java was not found in PATH'
        return
    fi

    java_version="$(doctor_java_version)" || true

    if [[ -n "$java_version" ]]; then
        _doctor_pass "Java found: $java_version"
    else
        _doctor_pass "Java found: $java_path"
    fi
}

_doctor_check_gradle_wrapper() {
    local project_root="$1"
    local wrapper="$project_root/gradlew"

    if [[ ! -f "$wrapper" ]]; then
        _doctor_fail "Gradle Wrapper does not exist: $wrapper"
        return
    fi

    if [[ ! -r "$wrapper" ]]; then
        _doctor_fail "Gradle Wrapper is not readable: $wrapper"
        return
    fi

    if [[ ! -x "$wrapper" ]]; then
        _doctor_warn "Gradle Wrapper is not executable: $wrapper"
        return
    fi

    _doctor_pass "Gradle Wrapper found: $wrapper"
}

_doctor_resolve_sdk_root() {
    if [[ -n "${ANDROID_HOME:-}" ]]; then
        printf '%s\n' "$ANDROID_HOME"
        return
    fi

    if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
        printf '%s\n' "$ANDROID_SDK_ROOT"
        return
    fi

    return 1
}

_doctor_check_android_sdk() {
    local sdk_root

    sdk_root="$(_doctor_resolve_sdk_root)" || true

    if [[ -z "$sdk_root" ]]; then
        _doctor_fail 'Neither ANDROID_HOME nor ANDROID_SDK_ROOT is set'
        return
    fi

    if [[ ! -d "$sdk_root" ]]; then
        _doctor_fail "Android SDK directory does not exist: $sdk_root"
        return
    fi

    _doctor_pass "Android SDK found: $sdk_root"
}

_doctor_check_adb() {
    local adb_path devices_output

    adb_path="$(doctor_command_path adb)" || true

    if [[ -z "$adb_path" ]]; then
        _doctor_warn 'ADB was not found in PATH'
        return
    fi

    _doctor_pass "ADB found: $adb_path"

    devices_output="$(doctor_adb_devices)" || true

    if printf '%s\n' "$devices_output" |
        grep -Eq $'\tdevice$'; then
        _doctor_pass 'At least one authorized ADB device is connected'
    else
        _doctor_warn 'No authorized ADB device is connected'
    fi
}

_doctor_find_manifest() {
    local project_root="$1"
    local common_manifest="$project_root/app/src/main/AndroidManifest.xml"

    if [[ -f "$common_manifest" ]]; then
        printf '%s\n' "$common_manifest"
        return
    fi

    find "$project_root" \
        -type f \
        -path '*/src/main/AndroidManifest.xml' \
        -print \
        -quit 2>/dev/null
}

_doctor_check_manifest() {
    local project_root="$1"
    local manifest

    manifest="$(_doctor_find_manifest "$project_root")" || true

    if [[ -n "$manifest" ]]; then
        _doctor_pass "Android manifest found: $manifest"
    else
        _doctor_warn 'No AndroidManifest.xml was found'
    fi
}

_doctor_find_apk_output() {
    local project_root="$1"

    find "$project_root" \
        -type d \
        -path '*/build/outputs/apk' \
        -print \
        -quit 2>/dev/null
}

_doctor_check_apk_output() {
    local project_root="$1"
    local apk_output

    apk_output="$(_doctor_find_apk_output "$project_root")" || true

    if [[ -n "$apk_output" ]]; then
        _doctor_pass "APK output directory found: $apk_output"
    else
        _doctor_warn 'No APK output directory exists yet'
    fi
}

_doctor_print_summary() {
    printf '\nDoctor summary\n'
    printf 'Passed: %s\n' "$DOCTOR_PASSED"
    printf 'Warnings: %s\n' "$DOCTOR_WARNINGS"
    printf 'Failed: %s\n' "$DOCTOR_FAILED"
}

doctor_run() {
    if (( $# != 1 )); then
        printf 'doctor: usage: doctor_run PROJECT_ROOT\n' >&2
        return 64
    fi

    local project_root="$1"

    if [[ -z "$project_root" ]]; then
        printf 'doctor: PROJECT_ROOT must not be empty\n' >&2
        return 64
    fi

    if [[ ! -d "$project_root" ]]; then
        printf 'doctor: project root does not exist: %s\n' \
            "$project_root" >&2
        return 1
    fi

    _doctor_reset

    printf 'TADK doctor\n'
    printf '%s\n' '----------------------------------------'

    _doctor_check_termux
    _doctor_check_bash
    _doctor_check_java
    _doctor_check_gradle_wrapper "$project_root"
    _doctor_check_android_sdk
    _doctor_check_adb
    _doctor_check_manifest "$project_root"
    _doctor_check_apk_output "$project_root"

    _doctor_print_summary

    if (( DOCTOR_FAILED != 0 )); then
        return 1
    fi
}
