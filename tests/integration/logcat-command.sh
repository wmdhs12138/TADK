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

mock_env_start_package "$PACKAGE_NAME"

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --lines 20 \
        --format brief \
        2>&1
)"

assert_contains \
    "$output" \
    "mock log" \
    "应输出模拟日志"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb shell pidof $PACKAGE_NAME" \
    "应解析应用 PID"

assert_contains \
    "$calls" \
    "adb logcat --pid=12345 -v brief -d -t 20" \
    "应按 PID 和参数读取日志"

mock_env_reset_log
: > "$MOCK_RUNNING_PACKAGES_FILE"

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --launch \
        --lines 5 \
        2>&1
)"

assert_contains \
    "$output" \
    "应用未运行，正在启动" \
    "--launch 应说明正在启动应用"

assert_contains \
    "$output" \
    "mock log" \
    "--launch 后应输出应用日志"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb shell monkey -p $PACKAGE_NAME" \
    "--launch 应启动应用"

assert_order \
    "$calls" \
    "adb shell monkey -p $PACKAGE_NAME" \
    "adb logcat --pid=12345" \
    "应用启动应先于日志读取"

assert_contains \
    "$(cat "$MOCK_RUNNING_PACKAGES_FILE")" \
    "$PACKAGE_NAME" \
    "--launch 后应用应处于运行状态"

mock_env_reset_log

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --clear-only \
        2>&1
)"

assert_contains \
    "$output" \
    "日志缓冲区已清空" \
    "clear-only 应成功"

assert_contains \
    "$(cat "$MOCK_LOG")" \
    "adb logcat -c" \
    "应调用 adb logcat -c"

mock_env_reset_log

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --all \
        --dump \
        --raw-output \
        2>&1
)"

assert_equals \
    "07-24 10:00:00.000 12345 12345 I MockApp: mock log" \
    "$output" \
    "raw-output 不应带标题"

assert_contains \
    "$(cat "$MOCK_LOG")" \
    "adb logcat -v threadtime -d" \
    "--all 应读取全部日志"

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --lines 0 \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "无效行数应失败"

assert_contains \
    "$output" \
    "必须是大于 0 的整数" \
    "应显示行数校验错误"

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --launch \
        --all \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "--launch 与 --all 同时使用应失败"

assert_contains \
    "$output" \
    "--launch 不能与 --all 同时使用" \
    "应显示选项冲突"

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --launch \
        --crash \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "--launch 与 --crash 同时使用应失败"

assert_contains \
    "$output" \
    "--launch 不能与 --crash 同时使用" \
    "应显示 launch 与 crash 冲突"

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --launch \
        --clear-only \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "--launch 与 --clear-only 同时使用应失败"

assert_contains \
    "$output" \
    "--launch 不能与 --clear-only 同时使用" \
    "应显示 launch 与 clear-only 冲突"

printf 'PASS: logcat command integration\n'
