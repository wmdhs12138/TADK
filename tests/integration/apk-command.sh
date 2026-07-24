#!/data/data/com.termux/files/usr/bin/bash

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
RELEASE_APK="$(mock_env_create_apk release)"

output="$(
    "$TADK_ROOT/bin/tadk" apk --path-only
)"

assert_equals \
    "$DEBUG_APK" \
    "$output" \
    "默认应返回 Debug APK"

output="$(
    "$TADK_ROOT/bin/tadk" \
        apk \
        --release \
        --path-only
)"

assert_equals \
    "$RELEASE_APK" \
    "$output" \
    "应返回 Release APK"

output="$(
    "$TADK_ROOT/bin/tadk" \
        apk \
        --path-only \
        --relative
)"

assert_equals \
    "app/build/outputs/apk/debug/app-debug.apk" \
    "$output" \
    "应返回项目相对路径"

output="$(
    "$TADK_ROOT/bin/tadk" \
        apk \
        --all \
        --path-only
)"

assert_contains \
    "$output" \
    "$DEBUG_APK" \
    "APK 列表应包含 Debug APK"

printf 'PASS: apk command integration\n'
