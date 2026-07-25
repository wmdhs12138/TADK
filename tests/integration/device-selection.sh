#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/tests/helpers/mock-env.sh"

trap mock_env_destroy EXIT

mock_env_create \
    "$TADK_ROOT/tests/fixtures/android-project"

cd "$MOCK_PROJECT"

PACKAGE_NAME="com.example.mockapp"
DEVICE_SERIAL="172.19.0.1:39439"

mock_env_start_package "$PACKAGE_NAME"

output="$(
    "$TADK_ROOT/bin/tadk" \
        launch \
        --device "$DEVICE_SERIAL" \
        --package "$PACKAGE_NAME" \
        --restart \
        2>&1
)"

assert_contains \
    "$output" \
    "目标设备：$DEVICE_SERIAL" \
    "launch 应显示选定设备"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL get-state" \
    "launch 应在选定设备上检查状态"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL shell am force-stop $PACKAGE_NAME" \
    "launch 应在选定设备上停止应用"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL shell monkey -p $PACKAGE_NAME" \
    "launch 应在选定设备上启动应用"

mock_env_reset_log
mock_env_start_package "$PACKAGE_NAME"

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --device "$DEVICE_SERIAL" \
        --package "$PACKAGE_NAME" \
        --lines 5 \
        2>&1
)"

assert_contains \
    "$output" \
    "目标设备：$DEVICE_SERIAL" \
    "logcat 应显示选定设备"

assert_contains \
    "$output" \
    "mock log" \
    "logcat 应输出选定设备日志"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL shell pidof $PACKAGE_NAME" \
    "logcat 应在选定设备上解析 PID"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL logcat --pid=12345" \
    "logcat 应读取选定设备日志"

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        launch \
        --device \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "缺少设备序列号时应失败"

assert_contains \
    "$output" \
    "--device 缺少设备序列号" \
    "应显示缺少设备序列号"

printf 'PASS: device selection integration\n'
