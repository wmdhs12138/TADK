#!/usr/bin/env bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/lib/doctor.sh"

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

create_healthy_project() {
    local root="$1"

    mkdir -p \
        "$root/app/src/main" \
        "$root/app/build/outputs/apk" \
        "$root/android-sdk"

    cat > "$root/gradlew" <<'GRADLEW'
#!/usr/bin/env bash
exit 0
GRADLEW

    chmod +x "$root/gradlew"

    cat > "$root/app/src/main/AndroidManifest.xml" <<'MANIFEST'
<manifest package="com.example.app" />
MANIFEST
}

mock_healthy_commands() {
    doctor_command_path() {
        case "$1" in
            bash)
                printf '/data/data/com.termux/files/usr/bin/bash\n'
                ;;
            java)
                printf '/data/data/com.termux/files/usr/bin/java\n'
                ;;
            adb)
                printf '/data/data/com.termux/files/usr/bin/adb\n'
                ;;
            *)
                return 1
                ;;
        esac
    }

    doctor_java_version() {
        printf 'openjdk version "17.0.12"\n'
    }

    doctor_adb_devices() {
        printf 'List of devices attached\n'
        printf 'emulator-5554\tdevice\n'
    }
}

case_requires_one_argument() {
    local output status=0

    output="$(doctor_run 2>&1)" || status=$?

    assert_equals '64' "$status"
    assert_contains "$output" 'usage: doctor_run PROJECT_ROOT [FORMAT]'
}

case_missing_project_root_fails() {
    local output status=0

    output="$(
        doctor_run '/path/that/does/not/exist' 2>&1
    )" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" 'project root does not exist'
}

case_healthy_environment_passes() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_healthy_project "$root"
    mock_healthy_commands

    export PREFIX='/data/data/com.termux/files/usr'
    export ANDROID_HOME="$root/android-sdk"
    unset ANDROID_SDK_ROOT

    output="$(doctor_run "$root" 2>&1)" || status=$?

    assert_success "$status"
    assert_contains "$output" 'PASS  Termux environment'
    assert_contains "$output" 'PASS  Bash found'
    assert_contains "$output" 'PASS  Java found: openjdk version'
    assert_contains "$output" 'PASS  Gradle Wrapper found'
    assert_contains "$output" 'PASS  Android SDK found'
    assert_contains "$output" 'PASS  ADB found'
    assert_contains "$output" \
        'PASS  At least one authorized ADB device is connected'
    assert_contains "$output" 'PASS  Android manifest found'
    assert_contains "$output" 'PASS  APK output directory found'
    assert_contains "$output" 'Warnings: 0'
    assert_contains "$output" 'Failed: 0'
}

case_json_output_is_machine_readable() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_healthy_project "$root"
    mock_healthy_commands

    export PREFIX='/data/data/com.termux/files/usr'
    export ANDROID_HOME="$root/android-sdk"
    unset ANDROID_SDK_ROOT

    output="$(doctor_run "$root" json 2>&1)" || status=$?

    assert_success "$status"
    assert_contains "$output" '"version":1'
    assert_contains "$output" '"project_root":"'
    assert_contains "$output" '"status":"pass"'
    assert_contains "$output" '"exit_code":0'
    assert_contains "$output" '"summary":{"passed":'
    assert_contains "$output" '"checks":['
    assert_contains "$output" '"message":"Termux environment:'
    assert_not_contains "$output" 'TADK doctor'
    assert_not_contains "$output" 'PASS  '
}

case_json_missing_project_returns_failure() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    output="$(doctor_run "$root/missing" json 2>&1)" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" '"status":"fail"'
    assert_contains "$output" '"exit_code":1'
    assert_contains "$output" 'project root does not exist'
}

case_warnings_do_not_fail_run() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_healthy_project "$root"
    mock_healthy_commands

    doctor_adb_devices() {
        printf 'List of devices attached\n'
    }

    export PREFIX='/usr'
    export ANDROID_HOME="$root/android-sdk"
    unset ANDROID_SDK_ROOT

    output="$(doctor_run "$root" 2>&1)" || status=$?

    assert_success "$status"
    assert_contains "$output" \
        'WARN  Termux environment was not detected'
    assert_contains "$output" \
        'WARN  No authorized ADB device is connected'
    assert_contains "$output" 'Failed: 0'
}

case_missing_java_is_hard_failure() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_healthy_project "$root"
    mock_healthy_commands

    doctor_command_path() {
        case "$1" in
            bash)
                printf '/usr/bin/bash\n'
                ;;
            adb)
                printf '/usr/bin/adb\n'
                ;;
            java)
                return 1
                ;;
        esac
    }

    export PREFIX='/data/data/com.termux/files/usr'
    export ANDROID_HOME="$root/android-sdk"
    unset ANDROID_SDK_ROOT

    output="$(doctor_run "$root" 2>&1)" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" 'FAIL  Java was not found in PATH'
    assert_contains "$output" 'Failed: 1'
}

case_missing_sdk_is_hard_failure() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_healthy_project "$root"
    mock_healthy_commands

    export PREFIX='/data/data/com.termux/files/usr'
    unset ANDROID_HOME
    unset ANDROID_SDK_ROOT

    output="$(doctor_run "$root" 2>&1)" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        'FAIL  Neither ANDROID_HOME nor ANDROID_SDK_ROOT is set'
    assert_contains "$output" 'Failed: 1'
}

case_missing_gradle_wrapper_is_hard_failure() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_healthy_project "$root"
    rm "$root/gradlew"
    mock_healthy_commands

    export PREFIX='/data/data/com.termux/files/usr'
    export ANDROID_HOME="$root/android-sdk"
    unset ANDROID_SDK_ROOT

    output="$(doctor_run "$root" 2>&1)" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        'FAIL  Gradle Wrapper does not exist'
    assert_contains "$output" 'Failed: 1'
}

case_missing_adb_is_warning() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_healthy_project "$root"
    mock_healthy_commands

    doctor_command_path() {
        case "$1" in
            bash)
                printf '/usr/bin/bash\n'
                ;;
            java)
                printf '/usr/bin/java\n'
                ;;
            adb)
                return 1
                ;;
        esac
    }

    export PREFIX='/data/data/com.termux/files/usr'
    export ANDROID_HOME="$root/android-sdk"
    unset ANDROID_SDK_ROOT

    output="$(doctor_run "$root" 2>&1)" || status=$?

    assert_success "$status"
    assert_contains "$output" 'WARN  ADB was not found in PATH'
    assert_contains "$output" 'Failed: 0'
}

case_android_sdk_root_fallback_works() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_healthy_project "$root"
    mock_healthy_commands

    export PREFIX='/data/data/com.termux/files/usr'
    unset ANDROID_HOME
    export ANDROID_SDK_ROOT="$root/android-sdk"

    output="$(doctor_run "$root" 2>&1)" || status=$?

    assert_success "$status"
    assert_contains "$output" \
        "PASS  Android SDK found: $root/android-sdk"
}

run_case \
    'requires one argument' \
    case_requires_one_argument

run_case \
    'missing project root fails' \
    case_missing_project_root_fails

run_case \
    'healthy environment passes' \
    case_healthy_environment_passes

run_case \
    'JSON output is machine-readable' \
    case_json_output_is_machine_readable

run_case \
    'JSON missing project returns failure' \
    case_json_missing_project_returns_failure

run_case \
    'warnings do not fail the run' \
    case_warnings_do_not_fail_run

run_case \
    'missing Java is a hard failure' \
    case_missing_java_is_hard_failure

run_case \
    'missing SDK is a hard failure' \
    case_missing_sdk_is_hard_failure

run_case \
    'missing Gradle Wrapper is a hard failure' \
    case_missing_gradle_wrapper_is_hard_failure

run_case \
    'missing ADB is a warning' \
    case_missing_adb_is_warning


case_nested_example_project_is_ignored() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    mkdir -p \
        "$root/templates/compose-app/app/src/main" \
        "$root/templates/compose-app/app/build/outputs/apk" \
        "$root/android-sdk"

    cat > "$root/templates/compose-app/gradlew" <<'GRADLEW'
#!/usr/bin/env bash
exit 0
GRADLEW

    chmod +x "$root/templates/compose-app/gradlew"

    cat > \
        "$root/templates/compose-app/app/src/main/AndroidManifest.xml" \
        <<'MANIFEST'
<manifest package="com.example.template" />
MANIFEST

    mock_healthy_commands

    export PREFIX='/data/data/com.termux/files/usr'
    export ANDROID_HOME="$root/android-sdk"
    unset ANDROID_SDK_ROOT

    output="$(doctor_run "$root" 2>&1)" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        "FAIL  Gradle Wrapper does not exist: $root/gradlew"
    assert_contains "$output" \
        'WARN  No AndroidManifest.xml was found'
    assert_contains "$output" \
        'WARN  No APK output directory exists yet'
    assert_not_contains "$output" \
        "$root/templates/compose-app/app/src/main/AndroidManifest.xml"
    assert_not_contains "$output" \
        "$root/templates/compose-app/app/build/outputs/apk"
}

run_case \
    'ANDROID_SDK_ROOT fallback works' \
    case_android_sdk_root_fallback_works


run_case \
    'nested example project is ignored' \
    case_nested_example_project_is_ignored

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All doctor library unit tests passed.\n'
