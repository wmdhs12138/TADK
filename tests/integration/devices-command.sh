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

json_output="$(
    "$TADK_ROOT/bin/tadk" \
        devices \
        --json \
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

assert_contains \
    "$json_output" \
    '"version":1' \
    "JSON 应包含诊断版本"

assert_contains \
    "$json_output" \
    '"status":"pass"' \
    "有可用设备时 JSON 状态应为 pass"

assert_contains \
    "$json_output" \
    '"summary":{"total":2,"available":1}' \
    "JSON 应统计设备数量"

assert_contains \
    "$json_output" \
    '"serial":"192.168.1.20:37123"' \
    "JSON 应包含无线设备序列号"

assert_contains \
    "$json_output" \
    '"manufacturer":"MockCorp"' \
    "JSON 应包含设备制造商"

assert_contains \
    "$json_output" \
    '"connection_type":"wireless"' \
    "JSON 应使用稳定的连接类型"

assert_contains \
    "$json_output" \
    '"state":"unauthorized"' \
    "JSON 应包含未授权设备"

assert_not_contains \
    "$json_output" \
    'TADK Devices' \
    "JSON 不应混入文本标题"

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

set +e

json_output="$(
    "$TADK_ROOT/bin/tadk" \
        devices \
        --json \
        2>&1
)"
json_exit_code=$?

set -e

assert_failure \
    "$json_exit_code" \
    "没有 ADB 设备时 JSON 应失败"

assert_contains \
    "$json_output" \
    '"status":"fail"' \
    "没有设备时 JSON 状态应为 fail"

assert_contains \
    "$json_output" \
    '"exit_code":1' \
    "没有设备时 JSON 应包含失败退出码"

assert_contains \
    "$json_output" \
    '"summary":{"total":0,"available":0}' \
    "没有设备时 JSON 应返回空统计"

assert_not_contains \
    "$json_output" \
    'TADK Devices' \
    "失败 JSON 不应混入文本标题"

printf 'PASS: devices command integration\n'
