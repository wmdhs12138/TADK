#!/usr/bin/env bash
set -Eeuo pipefail
TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/tests/helpers/mock-env.sh"
trap mock_env_destroy EXIT
mock_env_create "$TADK_ROOT/tests/fixtures/android-project"
cd "$MOCK_PROJECT"

output="$("$TADK_ROOT/bin/tadk" dev --lines 10 --format brief 2>&1)"
assert_contains "$output" "步骤 1/5：构建 APK" "应执行构建步骤"
assert_contains "$output" "步骤 5/5：应用日志" "应执行日志步骤"
assert_contains "$output" "mock log" "应输出应用日志"
calls="$(cat "$MOCK_LOG")"
assert_order "$calls" "./gradlew assembleDebug" "adb install -r" "构建应先于安装"
assert_order "$calls" "adb install -r" "adb logcat -c" "安装应先于清日志"
assert_order "$calls" "adb logcat -c" "adb shell monkey" "清日志应先于启动"
assert_order "$calls" "adb shell monkey" "adb logcat --pid=12345" "启动应先于日志"

mock_env_reset_log
output="$("$TADK_ROOT/bin/tadk" dev --no-clear --no-restart --no-logcat --release --clean --no-cache --rerun 2>&1)"
assert_contains "$output" "开发流程完成" "无日志模式应正常结束"
calls="$(cat "$MOCK_LOG")"
assert_contains "$calls" "./gradlew clean" "应执行 clean"
assert_contains "$calls" "./gradlew assembleRelease" "应构建 Release"
assert_not_contains "$calls" "adb logcat -c" "--no-clear 不应清日志"
assert_not_contains "$calls" "adb shell am force-stop" "--no-restart 不应停止应用"
assert_not_contains "$calls" "adb logcat --pid" "--no-logcat 不应读取日志"

mock_env_reset_log
mock_env_set_gradle_exit_code 9
set +e
output="$("$TADK_ROOT/bin/tadk" dev --no-logcat 2>&1)"; exit_code=$?
set -e
assert_failure "$exit_code" "构建失败时 dev 应立即失败"
assert_not_contains "$(cat "$MOCK_LOG")" "adb install" "构建失败后不应安装"
printf 'PASS: dev command integration\n'
