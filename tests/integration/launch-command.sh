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

PACKAGE_NAME="com.example.mockapp"

mock_env_install_package "$PACKAGE_NAME"

output="$(
    "$TADK_ROOT/bin/tadk" launch 2>&1
)"

assert_contains \
    "$output" \
    "应用已启动" \
    "Launch 应成功"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb shell pm list packages $PACKAGE_NAME" \
    "启动前应检查应用是否安装"

assert_contains \
    "$calls" \
    "adb shell monkey -p $PACKAGE_NAME" \
    "应通过 monkey 启动应用"

assert_file_exists \
    "$MOCK_RUNNING_PACKAGES_FILE"

assert_contains \
    "$(cat "$MOCK_RUNNING_PACKAGES_FILE")" \
    "$PACKAGE_NAME" \
    "应用启动后应处于运行状态"

: > "$MOCK_LOG"

"$TADK_ROOT/bin/tadk" \
    launch \
    --restart \
    >/dev/null

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb shell am force-stop $PACKAGE_NAME" \
    "--restart 应先停止应用"

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        launch \
        com.example.notinstalled \
        2>&1
)"
exit_code=$?
set -e

assert_failure \
    "$exit_code" \
    "未安装的应用不应启动成功"

assert_contains \
    "$output" \
    "设备上未安装应用" \
    "应显示未安装提示"

printf 'PASS: launch command integration\n'
