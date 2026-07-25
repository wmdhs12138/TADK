#!/usr/bin/env bash

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
: > "$MOCK_RUNNING_PACKAGES_FILE"
mock_env_install_package "$PACKAGE_NAME"

(
    sleep 0.5
    printf '%s\n' \
        "$PACKAGE_NAME" \
        >> "$MOCK_RUNNING_PACKAGES_FILE"
) &
wait_starter_pid=$!

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --wait \
        --lines 5 \
        2>&1
)"

wait "$wait_starter_pid"

assert_contains \
    "$output" \
    "等待应用启动" \
    "--wait 应说明正在等待应用"

assert_contains \
    "$output" \
    "mock log" \
    "--wait 检测到进程后应输出日志"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb shell pidof $PACKAGE_NAME" \
    "--wait 应轮询应用 PID"

assert_contains \
    "$calls" \
    "adb logcat --pid=12345" \
    "--wait 应按检测到的 PID 读取日志"

assert_not_contains \
    "$calls" \
    "adb shell monkey" \
    "--wait 不应主动启动应用"

assert_not_contains \
    "$calls" \
    "adb shell am force-stop" \
    "--wait 不应停止应用"

mock_env_reset_log
mock_env_start_package "$PACKAGE_NAME"

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --restart \
        --clear \
        --lines 5 \
        2>&1
)"

assert_contains \
    "$output" \
    "停止应用" \
    "--restart 应说明正在停止应用"

assert_contains \
    "$output" \
    "mock log" \
    "--restart 后应输出应用日志"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb shell am force-stop $PACKAGE_NAME" \
    "--restart 应强制停止应用"

assert_contains \
    "$calls" \
    "adb logcat -c" \
    "--restart --clear 应清空日志"

assert_contains \
    "$calls" \
    "adb shell monkey -p $PACKAGE_NAME" \
    "--restart 应重新启动应用"

assert_order \
    "$calls" \
    "adb shell am force-stop $PACKAGE_NAME" \
    "adb logcat -c" \
    "停止应用应先于清空日志"

assert_order \
    "$calls" \
    "adb logcat -c" \
    "adb shell monkey -p $PACKAGE_NAME" \
    "清空日志应先于重新启动"

assert_order \
    "$calls" \
    "adb shell monkey -p $PACKAGE_NAME" \
    "adb logcat --pid=12345" \
    "重新启动应先于读取日志"

assert_contains \
    "$(cat "$MOCK_RUNNING_PACKAGES_FILE")" \
    "$PACKAGE_NAME" \
    "--restart 后应用应重新运行"

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

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --restart \
        --all \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "--restart 与 --all 同时使用应失败"

assert_contains \
    "$output" \
    "--restart 不能与 --all 同时使用" \
    "应显示 restart 与 all 冲突"

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --restart \
        --crash \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "--restart 与 --crash 同时使用应失败"

assert_contains \
    "$output" \
    "--restart 不能与 --crash 同时使用" \
    "应显示 restart 与 crash 冲突"

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --restart \
        --clear-only \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "--restart 与 --clear-only 同时使用应失败"

assert_contains \
    "$output" \
    "--restart 不能与 --clear-only 同时使用" \
    "应显示 restart 与 clear-only 冲突"

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --wait \
        --launch \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "--wait 与 --launch 同时使用应失败"

assert_contains \
    "$output" \
    "--wait 不能与 --launch 或 --restart 同时使用" \
    "应显示 wait 与 launch 冲突"

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        logcat \
        --wait \
        --all \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "--wait 与 --all 同时使用应失败"

assert_contains \
    "$output" \
    "--wait 不能与 --all 同时使用" \
    "应显示 wait 与 all 冲突"

printf 'PASS: logcat command integration\n'
