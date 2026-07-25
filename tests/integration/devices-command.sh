#!/usr/bin/env bash

set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$TADK_ROOT/tests/helpers/assertions.sh"
source "$TADK_ROOT/tests/helpers/mock-env.sh"

trap mock_env_destroy EXIT

mock_env_create \
    "$TADK_ROOT/tests/fixtures/android-project"

cat > "$MOCK_BIN/adb" <<'MOCK_ADB'
#!/usr/bin/env bash

set -Eeuo pipefail

printf 'adb' >> "$MOCK_LOG"

for argument in "$@"; do
    printf ' %q' "$argument" >> "$MOCK_LOG"
done

printf '\n' >> "$MOCK_LOG"

if [[ "${1:-}" == "devices" && "${2:-}" == "-l" ]]; then
    cat <<'DEVICES'
List of devices attached
192.168.1.20:37123 device product:mock_product model:Mock_Phone device:mock transport_id:1
USB123 unauthorized usb:1-1 transport_id:2
DEVICES
    exit 0
fi

if [[ "${1:-}" != "-s" ]]; then
    printf 'Unsupported adb arguments\n' >&2
    exit 1
fi

serial="${2:-}"
shift 2

[[ "$serial" == "192.168.1.20:37123" ]] || {
    printf 'Unsupported serial: %s\n' "$serial" >&2
    exit 1
}

if [[ "${1:-}" != "shell" ]]; then
    printf 'Unsupported adb command: %s\n' "${1:-}" >&2
    exit 1
fi

shift

case "${1:-}" in
    getprop)
        case "${2:-}" in
            ro.product.manufacturer)
                printf 'MockCorp\n'
                ;;
            ro.product.model)
                printf 'Mock Phone Pro\n'
                ;;
            ro.build.version.release)
                printf '16\n'
                ;;
            ro.build.version.sdk)
                printf '36\n'
                ;;
            *)
                exit 1
                ;;
        esac
        ;;

    dumpsys)
        if [[ "${2:-}" == "activity" &&
              "${3:-}" == "activities" ]]; then
            printf '%s\n' \
                'mResumedActivity: ActivityRecord{abc u0 com.example.mockapp/.MainActivity t1}'
            exit 0
        fi

        if [[ "${2:-}" == "window" &&
              "${3:-}" == "windows" ]]; then
            printf '%s\n' \
                'mCurrentFocus=Window{abc u0 com.example.mockapp/com.example.mockapp.MainActivity}'
            exit 0
        fi

        exit 1
        ;;

    *)
        printf 'Unsupported adb shell command: %s\n' "${1:-}" >&2
        exit 1
        ;;
esac
MOCK_ADB

chmod +x "$MOCK_BIN/adb"

output="$(
    "$TADK_ROOT/bin/tadk" \
        devices \
        2>&1
)"

assert_contains \
    "$output" \
    "MockCorp Mock Phone Pro" \
    "应显示设备制造商和型号"

assert_contains \
    "$output" \
    "Android：16" \
    "应显示 Android 版本"

assert_contains \
    "$output" \
    "SDK：36" \
    "应显示 SDK 版本"

assert_contains \
    "$output" \
    "连接：无线调试" \
    "网络序列号应识别为无线调试"

assert_contains \
    "$output" \
    "无线地址：192.168.1.20:37123" \
    "应显示无线调试地址"

assert_contains \
    "$output" \
    "前台应用：com.example.mockapp" \
    "应显示当前前台应用"

assert_contains \
    "$output" \
    "状态：unauthorized" \
    "应显示未授权设备"

assert_contains \
    "$output" \
    "请在设备上允许 USB/无线调试授权" \
    "应提示如何处理未授权设备"

assert_contains \
    "$output" \
    "设备总数：2" \
    "应统计所有 ADB 设备"

assert_contains \
    "$output" \
    "可用设备：1" \
    "应统计可用设备"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb devices -l" \
    "应读取 ADB 设备列表"

assert_contains \
    "$calls" \
    "adb -s 192.168.1.20:37123 shell getprop ro.product.model" \
    "应按设备序列号查询型号"

assert_contains \
    "$calls" \
    "adb -s 192.168.1.20:37123 shell dumpsys activity activities" \
    "应查询当前前台应用"

cat > "$MOCK_BIN/adb" <<'MOCK_EMPTY_ADB'
#!/usr/bin/env bash

set -Eeuo pipefail

if [[ "${1:-}" == "devices" && "${2:-}" == "-l" ]]; then
    printf 'List of devices attached\n\n'
    exit 0
fi

exit 1
MOCK_EMPTY_ADB

chmod +x "$MOCK_BIN/adb"

set +e

output="$(
    "$TADK_ROOT/bin/tadk" \
        devices \
        2>&1
)"
exit_code=$?

set -e

assert_failure \
    "$exit_code" \
    "没有 ADB 设备时应失败"

assert_contains \
    "$output" \
    "未发现 ADB 设备" \
    "没有设备时应显示明确提示"

printf 'PASS: devices command integration\n'
