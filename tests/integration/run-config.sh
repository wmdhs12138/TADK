#!/usr/bin/env bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_WORK_ROOT="$HOME/.cache/tadk/tests/run-config.$$"

source "$TADK_ROOT/tests/helpers/assertions.sh"

PASSED=0
FAILED=0

mkdir -p "$TEST_WORK_ROOT"
trap 'rm -rf "$TEST_WORK_ROOT"' EXIT

new_test_root() {
    mktemp -d "$TEST_WORK_ROOT/case.XXXXXX"
}

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

create_project() {
    local root="$1"

    mkdir -p "$root/app" "$root/mobile"

    cat > "$root/settings.gradle.kts" <<'SETTINGS'
rootProject.name = "RunConfigTest"
include(":app")
include(":mobile")
SETTINGS

    cat > "$root/app/build.gradle.kts" <<'BUILD'
plugins {
    id("com.android.application")
}
BUILD

    cat > "$root/mobile/build.gradle.kts" <<'BUILD'
plugins {
    id("com.android.application")
}
BUILD

    cat > "$root/gradlew" <<'GRADLEW'
#!/usr/bin/env bash

set -Eeuo pipefail

printf '%s\n' "$*" >> "$PWD/gradle-calls.log"

task="${1:-}"

case "$task" in
    assembleDebug)
        module=app
        variant=debug
        filename=legacy-debug.apk
        ;;

    assembleRelease)
        module=app
        variant=release
        filename=legacy-release.apk
        ;;

    :*:assembleDebug)
        module="${task#:}"
        module="${module%%:*}"
        variant=debug
        filename="$module-debug.apk"
        ;;

    :*:assembleRelease)
        module="${task#:}"
        module="${module%%:*}"
        variant=release
        filename="$module-release.apk"
        ;;

    clean)
        exit 0
        ;;

    *)
        exit 9
        ;;
esac

output="$PWD/$module/build/outputs/apk/$variant"
mkdir -p "$output"
printf 'apk\n' > "$output/$filename"
GRADLEW

    chmod +x "$root/gradlew"
}

write_config() {
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

run_command() {
    local root="$1"
    shift

    (
        cd "$root"
        "$TADK_ROOT/bin/tadk" run "$@"
    )
}

case_config_builds_module_release() {
    local root output calls status=0

    root="$(new_test_root)"
    create_project "$root"
    write_config "$root" mobile release

    output="$(run_command "$root" --build-only 2>&1)" ||
        status=$?

    assert_success "$status"

    calls="$(cat "$root/gradle-calls.log")"

    assert_contains "$calls" \
        ':mobile:assembleRelease --console=plain'
    assert_contains "$output" '模块：mobile'
    assert_contains "$output" '类型：release'
    assert_contains "$output" 'mobile-release.apk'
}

case_cli_debug_overrides_config() {
    local root calls status=0

    root="$(new_test_root)"
    create_project "$root"
    write_config "$root" mobile release

    run_command "$root" --debug --build-only \
        >/dev/null 2>&1 ||
        status=$?

    assert_success "$status"

    calls="$(cat "$root/gradle-calls.log")"

    assert_contains "$calls" \
        ':mobile:assembleDebug --console=plain'
    assert_not_contains "$calls" \
        ':mobile:assembleRelease'
}

case_without_config_uses_legacy_task() {
    local root output calls status=0

    root="$(new_test_root)"
    create_project "$root"

    output="$(run_command "$root" --build-only 2>&1)" ||
        status=$?

    assert_success "$status"

    calls="$(cat "$root/gradle-calls.log")"

    assert_contains "$calls" \
        'assembleDebug --console=plain'
    assert_not_contains "$calls" \
        ':app:assembleDebug'
    assert_contains "$output" \
        '配置：未找到，使用兼容模式'
    assert_contains "$output" 'legacy-debug.apk'
}

case_invalid_config_prevents_build() {
    local root output status=0

    root="$(new_test_root)"
    create_project "$root"
    write_config "$root" app benchmark

    output="$(run_command "$root" --build-only 2>&1)" ||
        status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        "invalid variant 'benchmark'"
    assert_file_not_exists "$root/gradle-calls.log"
}

case_missing_module_prevents_build() {
    local root output status=0

    root="$(new_test_root)"
    create_project "$root"
    write_config "$root" missing debug

    output="$(run_command "$root" --build-only 2>&1)" ||
        status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        "配置的模块目录不存在：$root/missing"
    assert_file_not_exists "$root/gradle-calls.log"
}

case_gradle_arguments_are_preserved() {
    local root calls status=0

    root="$(new_test_root)"
    create_project "$root"
    write_config "$root" app debug

    run_command \
        "$root" \
        --build-only \
        --clean \
        --no-cache \
        --rerun \
        -- \
        --stacktrace \
        >/dev/null 2>&1 ||
        status=$?

    assert_success "$status"

    calls="$(cat "$root/gradle-calls.log")"

    assert_contains "$calls" \
        'clean --console=plain --no-build-cache --rerun-tasks --stacktrace'
    assert_contains "$calls" \
        ':app:assembleDebug --console=plain --no-build-cache --rerun-tasks --stacktrace'
}

run_case \
    'config builds module release' \
    case_config_builds_module_release

run_case \
    'CLI debug overrides config' \
    case_cli_debug_overrides_config

run_case \
    'without config uses legacy task' \
    case_without_config_uses_legacy_task

run_case \
    'invalid config prevents build' \
    case_invalid_config_prevents_build

run_case \
    'missing module prevents build' \
    case_missing_module_prevents_build

run_case \
    'Gradle arguments are preserved' \
    case_gradle_arguments_are_preserved

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All run configuration integration tests passed.\n'
