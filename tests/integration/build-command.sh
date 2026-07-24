#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/tests/helpers/mock-env.sh"
trap mock_env_destroy EXIT
mock_env_create "$TADK_ROOT/tests/fixtures/android-project"
cd "$MOCK_PROJECT"

output="$("$TADK_ROOT/bin/tadk" build 2>&1)"
assert_contains "$output" "构建成功" "Debug 构建应成功"
assert_file_exists "$MOCK_PROJECT/app/build/outputs/apk/debug/app-debug.apk"
calls="$(cat "$MOCK_LOG")"
assert_contains "$calls" "./gradlew assembleDebug --console=plain" "默认应执行 assembleDebug"

mock_env_reset_log
output="$("$TADK_ROOT/bin/tadk" build --release --clean --no-cache --rerun -- --stacktrace 2>&1)"
assert_contains "$output" "构建成功" "Release 构建应成功"
assert_file_exists "$MOCK_PROJECT/app/build/outputs/apk/release/app-release.apk"
calls="$(cat "$MOCK_LOG")"
assert_order "$calls" "./gradlew clean" "./gradlew assembleRelease" "clean 应先于 release 构建"
assert_contains "$calls" "--no-build-cache" "应透传 no-cache"
assert_contains "$calls" "--rerun-tasks" "应透传 rerun"
assert_contains "$calls" "--stacktrace" "应透传 Gradle 参数"

mock_env_set_gradle_exit_code 7
set +e
output="$("$TADK_ROOT/bin/tadk" build 2>&1)"; exit_code=$?
set -e
assert_failure "$exit_code" "Gradle 失败时 build 应失败"
assert_contains "$output" "FAILURE: Build failed" "应保留 Gradle 错误"
printf 'PASS: build command integration\n'
