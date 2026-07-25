#!/data/data/com.termux/files/usr/bin/bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$TADK_ROOT/tests/helpers/assertions.sh"

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

create_fake_adb() {
    local root="$1"

    mkdir -p "$root/fake-bin"

    cat > "$root/fake-bin/adb" <<'ADB'
#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

case "${1:-}" in
    get-state)
        printf 'device\n'
        ;;

    install)
        printf '%s\n' "$*" >> "$TADK_TEST_ADB_LOG"
        printf 'Success\n'
        ;;

    *)
        printf 'unexpected adb command: %s\n' "$*" >&2
        exit 9
        ;;
esac
ADB

    chmod +x "$root/fake-bin/adb"
}

create_project() {
    local root="$1"

    mkdir -p \
        "$root/app/build/outputs/apk/debug" \
        "$root/app/build/outputs/apk/release" \
        "$root/mobile/build/outputs/apk/debug" \
        "$root/mobile/build/outputs/apk/release"

    cat > "$root/settings.gradle.kts" <<'SETTINGS'
rootProject.name = "InstallConfigTest"
include(":app")
include(":mobile")
SETTINGS

    cat > "$root/gradlew" <<'GRADLEW'
#!/data/data/com.termux/files/usr/bin/bash
exit 0
GRADLEW

    chmod +x "$root/gradlew"

    printf 'apk\n' > \
        "$root/app/build/outputs/apk/debug/app-debug.apk"

    printf 'apk\n' > \
        "$root/app/build/outputs/apk/release/app-release.apk"

    printf 'apk\n' > \
        "$root/mobile/build/outputs/apk/debug/mobile-debug.apk"

    printf 'apk\n' > \
        "$root/mobile/build/outputs/apk/release/mobile-release.apk"
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

run_install() {
    local root="$1"
    shift

    (
        cd "$root"

        PATH="$root/fake-bin:$PATH" \
        TADK_TEST_ADB_LOG="$root/adb.log" \
            "$TADK_ROOT/bin/tadk" install "$@"
    )
}

case_config_selects_module_release_apk() {
    local root output calls status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_fake_adb "$root"
    create_project "$root"
    write_config "$root" mobile release

    output="$(run_install "$root" 2>&1)" ||
        status=$?

    assert_success "$status"

    calls="$(cat "$root/adb.log")"

    assert_contains "$calls" \
        "$root/mobile/build/outputs/apk/release/mobile-release.apk"

    assert_not_contains "$calls" \
        "$root/app/build/outputs/apk/release/app-release.apk"

    assert_contains "$output" '模块：mobile'
    assert_contains "$output" '类型：release'
}

case_cli_debug_overrides_config_release() {
    local root calls status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_fake_adb "$root"
    create_project "$root"
    write_config "$root" mobile release

    run_install "$root" --debug \
        >/dev/null 2>&1 ||
        status=$?

    assert_success "$status"

    calls="$(cat "$root/adb.log")"

    assert_contains "$calls" \
        "$root/mobile/build/outputs/apk/debug/mobile-debug.apk"

    assert_not_contains "$calls" \
        'mobile-release.apk'
}

case_without_config_uses_legacy_resolution() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_fake_adb "$root"
    create_project "$root"

    touch \
        "$root/app/build/outputs/apk/debug/app-debug.apk"

    output="$(run_install "$root" 2>&1)" ||
        status=$?

    assert_success "$status"
    assert_contains "$output" \
        '配置：未找到，使用兼容模式'
    assert_contains "$output" \
        "$root/app/build/outputs/apk/debug/app-debug.apk"
}

case_explicit_apk_bypasses_project_config() {
    local root explicit output calls status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_fake_adb "$root"
    create_project "$root"
    write_config "$root" mobile release

    explicit="$root/app/build/outputs/apk/debug/app-debug.apk"

    output="$(run_install "$root" --apk "$explicit" 2>&1)" ||
        status=$?

    assert_success "$status"

    calls="$(cat "$root/adb.log")"

    assert_contains "$calls" "$explicit"
    assert_contains "$output" '来源：显式 APK 路径'
    assert_not_contains "$output" '模块：mobile'
}

case_invalid_config_prevents_adb_execution() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_fake_adb "$root"
    create_project "$root"
    write_config "$root" app benchmark

    output="$(run_install "$root" 2>&1)" ||
        status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        "invalid variant 'benchmark'"
    assert_contains "$output" \
        '无法加载项目配置，状态码：65'
    assert_file_not_exists "$root/adb.log"
}

case_missing_configured_module_prevents_adb() {
    local root output status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_fake_adb "$root"
    create_project "$root"
    write_config "$root" missing debug

    output="$(run_install "$root" 2>&1)" ||
        status=$?

    assert_equals '1' "$status"
    assert_contains "$output" \
        "配置的模块目录不存在：$root/missing"
    assert_file_not_exists "$root/adb.log"
}

case_install_options_are_preserved() {
    local root calls status=0

    root="$(mktemp -d)"
    trap 'rm -rf "$root"' RETURN

    create_fake_adb "$root"
    create_project "$root"
    write_config "$root" app debug

    run_install \
        "$root" \
        --downgrade \
        --grant \
        -- \
        --user 0 \
        >/dev/null 2>&1 ||
        status=$?

    assert_success "$status"

    calls="$(cat "$root/adb.log")"

    assert_contains "$calls" \
        'install -r -d -g --user 0'

    assert_contains "$calls" \
        "$root/app/build/outputs/apk/debug/app-debug.apk"
}

run_case \
    'config selects module release APK' \
    case_config_selects_module_release_apk

run_case \
    'CLI debug overrides config release' \
    case_cli_debug_overrides_config_release

run_case \
    'without config uses legacy resolution' \
    case_without_config_uses_legacy_resolution

run_case \
    'explicit APK bypasses project config' \
    case_explicit_apk_bypasses_project_config

run_case \
    'invalid config prevents ADB execution' \
    case_invalid_config_prevents_adb_execution

run_case \
    'missing configured module prevents ADB' \
    case_missing_configured_module_prevents_adb

run_case \
    'install options are preserved' \
    case_install_options_are_preserved

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All install configuration integration tests passed.\n'
