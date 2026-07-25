#!/usr/bin/env bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_ROOT="$HOME/.cache/tadk/tests/build-config.$$"
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

    mkdir -p "$root/app" "$root/mobile"

    cat > "$root/settings.gradle.kts" <<'SETTINGS'
rootProject.name = "BuildConfigTest"
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
    clean)
        exit 0
        ;;

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

    *)
        printf 'unexpected task: %s\n' "$task" >&2
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

run_build() {
    local root="$1"
    shift

    (
        cd "$root"
        "$TADK_ROOT/bin/tadk" build "$@"
    )
}

case_without_config_uses_legacy_debug() {
    local root output calls status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root"

    output="$(run_build "$root" 2>&1)" ||
        status=$?

    assert_success "$status"

    calls="$(cat "$root/gradle-calls.log")"

    assert_contains "$calls" \
        'assembleDebug --console=plain'
    assert_not_contains "$calls" \
        ':app:assembleDebug'
    assert_contains "$output" \
        '配置：未找到，使用兼容模式'
    assert_contains "$output" \
        '任务：assembleDebug'
    assert_contains "$output" \
        'legacy-debug.apk'
}

case_config_uses_module_and_variant() {
    local root output calls status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root"
    write_config "$root" mobile release

    output="$(run_build "$root" 2>&1)" ||
        status=$?

    assert_success "$status"

    calls="$(cat "$root/gradle-calls.log")"

    assert_contains "$calls" \
        ':mobile:assembleRelease --console=plain'
    assert_contains "$output" '模块：mobile'
    assert_contains "$output" '类型：release'
    assert_contains "$output" \
        '任务：:mobile:assembleRelease'
    assert_contains "$output" \
        'mobile-release.apk'
}

case_cli_debug_overrides_config_variant() {
    local root output calls status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root"
    write_config "$root" mobile release

    output="$(run_build "$root" --debug 2>&1)" ||
        status=$?

    assert_success "$status"

    calls="$(cat "$root/gradle-calls.log")"

    assert_contains "$calls" \
        ':mobile:assembleDebug --console=plain'
    assert_not_contains "$calls" \
        ':mobile:assembleRelease'
    assert_contains "$output" '类型：debug'
    assert_contains "$output" \
        'mobile-debug.apk'
}

case_cli_release_overrides_debug_config() {
    local root calls status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root"
    write_config "$root" app debug

    run_build "$root" --release \
        >/dev/null 2>&1 ||
        status=$?

    assert_success "$status"

    calls="$(cat "$root/gradle-calls.log")"

    assert_contains "$calls" \
        ':app:assembleRelease --console=plain'
}

case_gradle_arguments_are_preserved() {
    local root calls status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root"
    write_config "$root" app debug

    run_build \
        "$root" \
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

case_invalid_config_prevents_gradle_execution() {
    local root output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root"

    mkdir -p "$root/.tadk"

    cat > "$root/.tadk/project.conf" <<'CONFIG'
version=1
module=app
variant=benchmark
CONFIG

    output="$(run_build "$root" 2>&1)" ||
        status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        "invalid variant 'benchmark'"
    assert_contains "$output" \
        '无法加载项目配置，状态码：65'
    assert_file_not_exists "$root/gradle-calls.log"
}

case_missing_configured_module_prevents_build() {
    local root output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root"
    write_config "$root" missing debug

    output="$(run_build "$root" 2>&1)" ||
        status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        "配置的模块目录不存在：$root/missing"
    assert_file_not_exists "$root/gradle-calls.log"
}

case_module_apk_resolution_ignores_other_module() {
    local root output status=0

    new_case_root
    root="$CASE_ROOT"

    create_project "$root"
    write_config "$root" app debug

    mkdir -p "$root/mobile/build/outputs/apk/debug"
    printf 'other\n' > \
        "$root/mobile/build/outputs/apk/debug/newer.apk"

    touch \
        "$root/mobile/build/outputs/apk/debug/newer.apk"

    output="$(run_build "$root" 2>&1)" ||
        status=$?

    assert_success "$status"
    assert_contains "$output" \
        "$root/app/build/outputs/apk/debug/app-debug.apk"
    assert_not_contains "$output" \
        "$root/mobile/build/outputs/apk/debug/newer.apk"
}

run_case \
    'without config uses legacy debug' \
    case_without_config_uses_legacy_debug

run_case \
    'config uses module and variant' \
    case_config_uses_module_and_variant

run_case \
    'CLI debug overrides config variant' \
    case_cli_debug_overrides_config_variant

run_case \
    'CLI release overrides debug config' \
    case_cli_release_overrides_debug_config

run_case \
    'Gradle arguments are preserved' \
    case_gradle_arguments_are_preserved

run_case \
    'invalid config prevents Gradle execution' \
    case_invalid_config_prevents_gradle_execution

run_case \
    'missing configured module prevents build' \
    case_missing_configured_module_prevents_build

run_case \
    'module APK resolution ignores another module' \
    case_module_apk_resolution_ignores_other_module

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All build configuration integration tests passed.\n'
