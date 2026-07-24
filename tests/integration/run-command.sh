#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/tests/helpers/mock-env.sh"

trap mock_env_destroy EXIT

mock_env_create "$TADK_ROOT/tests/fixtures/android-project"

cat > "$MOCK_BIN/termux-open" <<'MOCK_TERMUX_OPEN'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

printf 'termux-open' >> "$MOCK_LOG"

for argument in "$@"; do
    printf ' %q' "$argument" >> "$MOCK_LOG"
done

printf '\n' >> "$MOCK_LOG"
MOCK_TERMUX_OPEN

chmod +x "$MOCK_BIN/termux-open"

cd "$MOCK_PROJECT"


# Default mode: build debug APK and open the system installer.
output="$("$TADK_ROOT/bin/tadk" run 2>&1)"

assert_contains "$output" "TADK Run" \
    "默认模式应显示 Run 标题"

assert_contains "$output" "模式：open" \
    "默认模式应为 open"

assert_contains "$output" "构建成功" \
    "默认模式应成功构建"

assert_contains "$output" "打开系统安装界面" \
    "默认模式应打开安装界面"

assert_contains "$output" "完成。" \
    "默认模式应正常完成"

calls="$(cat "$MOCK_LOG")"

assert_order \
    "$calls" \
    "./gradlew assembleDebug" \
    "termux-open" \
    "默认模式应先构建再打开 APK"

assert_not_contains "$calls" "adb install" \
    "默认 open 模式不应执行 adb install"


# Build-only mode: preserve build options and skip all installation actions.
mock_env_reset_log

output="$(
    "$TADK_ROOT/bin/tadk" run \
        --build-only \
        --release \
        --clean \
        --no-cache \
        --rerun \
        -- \
        --stacktrace \
        2>&1
)"

assert_contains "$output" "模式：none" \
    "build-only 模式应显示 none"

assert_contains "$output" "类型：release" \
    "应构建 Release APK"

assert_contains "$output" "仅构建模式，未执行安装。" \
    "build-only 模式应显示跳过安装提示"

calls="$(cat "$MOCK_LOG")"

assert_contains "$calls" "./gradlew clean" \
    "--clean 应执行 Gradle clean"

assert_contains "$calls" "./gradlew assembleRelease" \
    "应执行 Release 构建"

assert_contains "$calls" "--no-build-cache" \
    "--no-cache 应传递 Gradle 参数"

assert_contains "$calls" "--rerun-tasks" \
    "--rerun 应传递 Gradle 参数"

assert_contains "$calls" "--stacktrace" \
    "-- 后参数应透传给 Gradle"

assert_not_contains "$calls" "termux-open" \
    "build-only 不应打开安装界面"

assert_not_contains "$calls" "adb install" \
    "build-only 不应执行 adb install"


# ADB mode: build, install, then launch.
mock_env_reset_log

output="$("$TADK_ROOT/bin/tadk" run --install 2>&1)"

assert_contains "$output" "模式：adb" \
    "install 模式应显示 adb"

assert_contains "$output" "ADB 安装成功" \
    "ADB 模式应完成安装"

assert_contains "$output" "应用已启动" \
    "ADB 模式应尝试启动应用"

calls="$(cat "$MOCK_LOG")"

assert_order \
    "$calls" \
    "./gradlew assembleDebug" \
    "adb install -r" \
    "ADB 模式应先构建再安装"

assert_order \
    "$calls" \
    "adb install -r" \
    "adb shell monkey" \
    "ADB 模式应先安装再启动"

assert_not_contains "$calls" "termux-open" \
    "ADB 模式不应调用 termux-open"


# Build failure: workflow must stop before APK handling and installation.
mock_env_reset_log
mock_env_set_gradle_exit_code 9

set +e
output="$("$TADK_ROOT/bin/tadk" run --install 2>&1)"
exit_code=$?
set -e

assert_equals '9' "$exit_code" \
    "构建失败码应由 run 向上传播"

assert_not_contains "$(cat "$MOCK_LOG")" "adb install" \
    "构建失败后不得执行安装"

assert_not_contains "$(cat "$MOCK_LOG")" "termux-open" \
    "构建失败后不得打开安装界面"

assert_not_contains "$output" "完成。" \
    "构建失败后不得输出完成提示"

printf 'PASS: run command integration\n'
