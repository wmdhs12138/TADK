#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/tests/helpers/mock-env.sh"

trap mock_env_destroy EXIT

mock_env_create \
    "$TADK_ROOT/tests/fixtures/android-project"

cd "$MOCK_PROJECT"

DEBUG_APK="$(mock_env_create_apk debug)"

DEVICE_SERIAL="172.19.0.1:39439"
PACKAGE_NAME="com.example.mockapp"

output="$(
    "$TADK_ROOT/bin/tadk" \
        install \
        --device "$DEVICE_SERIAL" \
        2>&1
)"

assert_contains \
    "$output" \
    "目标设备：$DEVICE_SERIAL" \
    "install 应显示选定设备"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL get-state" \
    "install 应在选定设备上检查状态"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL install -r" \
    "install 应在选定设备上安装 APK"

mock_env_reset_log

output="$(
    "$TADK_ROOT/bin/tadk" \
        run \
        --install \
        --device "$DEVICE_SERIAL" \
        --logcat \
        2>&1
)"

assert_contains \
    "$output" \
    "目标设备：$DEVICE_SERIAL" \
    "run 应显示选定设备"

assert_contains \
    "$output" \
    "mock log" \
    "run 应输出选定设备日志"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL install -r" \
    "run 应在选定设备上安装 APK"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL shell monkey -p $PACKAGE_NAME" \
    "run 应在选定设备上启动应用"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL shell pidof $PACKAGE_NAME" \
    "run 应在选定设备上解析 PID"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL logcat --pid=12345" \
    "run 应在选定设备上读取日志"

mock_env_reset_log

output="$(
    "$TADK_ROOT/bin/tadk" \
        dev \
        --device "$DEVICE_SERIAL" \
        --lines 5 \
        2>&1
)"

assert_contains \
    "$output" \
    "目标设备：$DEVICE_SERIAL" \
    "dev 应显示选定设备"

assert_contains \
    "$output" \
    "mock log" \
    "dev 应输出选定设备日志"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL install -r" \
    "dev 应在选定设备上安装 APK"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL logcat -c" \
    "dev 应在选定设备上清空日志"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL shell am force-stop $PACKAGE_NAME" \
    "dev 应在选定设备上停止旧进程"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL shell monkey -p $PACKAGE_NAME" \
    "dev 应在选定设备上启动应用"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL shell pidof $PACKAGE_NAME" \
    "dev 应在选定设备上解析 PID"

assert_contains \
    "$calls" \
    "adb -s $DEVICE_SERIAL logcat --pid=12345" \
    "dev 应在选定设备上读取日志"

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        run \
        --device "$DEVICE_SERIAL" \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "run 默认 open 模式不应接受 --device"

assert_contains \
    "$output" \
    "--device 只能与 --install 模式同时使用" \
    "run 应提示 --device 依赖 --install"

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        install \
        --device \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "install 缺少设备序列号时应失败"

assert_contains \
    "$output" \
    "--device 缺少设备序列号" \
    "install 应显示缺少设备序列号"

printf 'PASS: workflow device selection integration\n'
