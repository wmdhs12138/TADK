#!/usr/bin/env bash

set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/tests/helpers/mock-env.sh"

cleanup() {
    mock_env_destroy
}

trap cleanup EXIT

mock_env_create \
    "$TADK_ROOT/tests/fixtures/android-project"

cd "$MOCK_PROJECT"

DEBUG_APK="$(mock_env_create_apk debug)"

output="$(
    "$TADK_ROOT/bin/tadk" install 2>&1
)"

assert_contains \
    "$output" \
    "Success" \
    "ADB 安装应成功"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb get-state" \
    "安装前应检查设备状态"

assert_contains \
    "$calls" \
    "adb install -r" \
    "默认应使用覆盖安装"

assert_contains \
    "$calls" \
    "$DEBUG_APK" \
    "应安装解析到的 Debug APK"

: > "$MOCK_LOG"

"$TADK_ROOT/bin/tadk" \
    install \
    --no-reinstall \
    "$DEBUG_APK" \
    >/dev/null

calls="$(cat "$MOCK_LOG")"

assert_not_contains \
    "$calls" \
    "adb install -r" \
    "--no-reinstall 不应使用 -r"

mock_env_set_adb_state offline

set +e
output="$(
    "$TADK_ROOT/bin/tadk" install 2>&1
)"
exit_code=$?
set -e

assert_failure \
    "$exit_code" \
    "离线设备时安装应失败"

assert_contains \
    "$output" \
    "ADB 设备未连接" \
    "应显示设备未连接错误"

printf 'PASS: install command integration\n'
