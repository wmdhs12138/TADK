#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/tests/helpers/mock-env.sh"

trap mock_env_destroy EXIT

mock_env_create \
    "$TADK_ROOT/tests/fixtures/android-project"

cd "$MOCK_PROJECT"

output="$(
    "$TADK_ROOT/bin/tadk" \
        run \
        --install \
        --logcat \
        2>&1
)"

assert_contains \
    "$output" \
    "ADB 安装成功" \
    "run --install --logcat 应安装 APK"

assert_contains \
    "$output" \
    "应用已启动" \
    "run --install --logcat 应启动应用"

assert_contains \
    "$output" \
    "进入应用日志" \
    "run --install --logcat 应进入日志阶段"

assert_contains \
    "$output" \
    "mock log" \
    "run --install --logcat 应输出应用日志"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb install -r" \
    "应通过 adb install -r 安装 APK"

assert_contains \
    "$calls" \
    "adb shell monkey -p com.example.mockapp" \
    "应启动已安装应用"

assert_contains \
    "$calls" \
    "adb shell pidof com.example.mockapp" \
    "应解析应用 PID"

assert_contains \
    "$calls" \
    "adb logcat --pid=12345" \
    "应按应用 PID 读取日志"

assert_order \
    "$calls" \
    "adb install -r" \
    "adb shell monkey -p com.example.mockapp" \
    "安装应先于启动"

assert_order \
    "$calls" \
    "adb shell monkey -p com.example.mockapp" \
    "adb logcat --pid=12345" \
    "启动应先于日志读取"

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        run \
        --logcat \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "未指定 --install 的 --logcat 应失败"

assert_contains \
    "$output" \
    "--logcat 必须与 --install 同时使用" \
    "应提示 --logcat 依赖 --install"

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        run \
        --build-only \
        --logcat \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "--build-only 与 --logcat 应失败"

assert_contains \
    "$output" \
    "--logcat 必须与 --install 同时使用" \
    "build-only 模式不能进入日志"

printf 'PASS: run logcat integration\n'
