#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/adb.sh"

DEVICES_JSON_OUTPUT=false
declare -a DEVICES_JSON_RECORDS=()

usage() {
    cat <<'HELP'
用法：
  tadk devices [--json]

说明：
  列出当前 ADB 可见设备，并显示设备型号、Android 版本、
  SDK、连接方式、无线调试地址和当前前台应用。

状态说明：
  device        设备已连接并授权
  unauthorized  设备尚未授权当前 ADB 客户端
  offline       设备离线
  no permissions
                当前环境没有访问设备的权限

选项：
  -h, --help            显示帮助
  --json                输出机器可读的 JSON 结果

示例：
  tadk devices
HELP
}

_devices_json_escape() {
    if (( $# != 1 )); then
        return 64
    fi

    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"

    printf '%s' "$value"
}

_devices_append_json_record() {
    if (( $# != 10 )); then
        return 64
    fi

    local serial="$1"
    local state="$2"
    local details="$3"
    local manufacturer="$4"
    local model="$5"
    local android_version="$6"
    local sdk_version="$7"
    local foreground_package="$8"
    local connection_type="$9"
    local wireless_address="${10}"
    local escaped_serial escaped_state escaped_details
    local escaped_manufacturer escaped_model escaped_android_version
    local escaped_sdk_version escaped_foreground_package
    local escaped_connection_type escaped_wireless_address
    local record

    escaped_serial="$(_devices_json_escape "$serial")"
    escaped_state="$(_devices_json_escape "$state")"
    escaped_details="$(_devices_json_escape "$details")"
    escaped_manufacturer="$(_devices_json_escape "$manufacturer")"
    escaped_model="$(_devices_json_escape "$model")"
    escaped_android_version="$(_devices_json_escape "$android_version")"
    escaped_sdk_version="$(_devices_json_escape "$sdk_version")"
    escaped_foreground_package="$(_devices_json_escape "$foreground_package")"
    escaped_connection_type="$(_devices_json_escape "$connection_type")"
    escaped_wireless_address="$(_devices_json_escape "$wireless_address")"

    printf -v record \
        '{"serial":"%s","state":"%s","details":"%s","manufacturer":"%s","model":"%s","android_version":"%s","sdk_version":"%s","foreground_package":"%s","connection_type":"%s","wireless_address":"%s"}' \
        "$escaped_serial" \
        "$escaped_state" \
        "$escaped_details" \
        "$escaped_manufacturer" \
        "$escaped_model" \
        "$escaped_android_version" \
        "$escaped_sdk_version" \
        "$escaped_foreground_package" \
        "$escaped_connection_type" \
        "$escaped_wireless_address"

    DEVICES_JSON_RECORDS+=("$record")
}

_devices_print_json() {
    local overall_status=fail
    local exit_code=1
    local index

    if (( ready_count != 0 )); then
        overall_status=pass
        exit_code=0
    fi

    printf '{"version":1,"status":"%s","exit_code":%s,' \
        "$overall_status" \
        "$exit_code"
    printf '"summary":{"total":%s,"available":%s},"devices":[' \
        "$device_count" \
        "$ready_count"

    for index in "${!DEVICES_JSON_RECORDS[@]}"; do
        if (( index > 0 )); then
            printf ','
        fi

        printf '%s' "${DEVICES_JSON_RECORDS[$index]}"
    done

    printf ']}\n'
}

_devices_print_json_failure() {
    if (( $# != 1 )); then
        return 64
    fi

    local escaped_message
    escaped_message="$(_devices_json_escape "$1")"

    printf '{"version":1,"status":"fail","exit_code":1,"error":"%s","summary":{"total":0,"available":0},"devices":[]}\n' \
        "$escaped_message"
}

adb_for_serial() {
    if (( $# < 2 )); then
        tadk_error \
            "内部错误：adb_for_serial 需要 SERIAL 和 ADB 参数"
        return 64
    fi

    local serial="$1"
    shift

    adb -s "$serial" "$@"
}

device_getprop() {
    if (( $# != 2 )); then
        tadk_error \
            "内部错误：device_getprop 需要 SERIAL 和 PROPERTY"
        return 64
    fi

    local serial="$1"
    local property_name="$2"

    adb_for_serial \
        "$serial" \
        shell \
        getprop \
        "$property_name" \
        2>/dev/null |
        tr -d '\r'
}

device_connection_type() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：device_connection_type 需要 SERIAL"
        return 64
    fi

    local serial="$1"

    if [[ "$serial" == *:* ]]; then
        printf '无线调试\n'
    else
        printf 'USB 或本地 ADB\n'
    fi
}

device_wireless_address() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：device_wireless_address 需要 SERIAL"
        return 64
    fi

    local serial="$1"

    if [[ "$serial" == *:* ]]; then
        printf '%s\n' "$serial"
    else
        printf '不适用\n'
    fi
}

device_foreground_package() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：device_foreground_package 需要 SERIAL"
        return 64
    fi

    local serial="$1"
    local package_name=""
    local activity_output=""
    local window_output=""
    local top_output=""

    activity_output="$(
        adb_for_serial \
            "$serial" \
            shell \
            dumpsys \
            activity \
            activities \
            2>/dev/null |
            tr -d '\r' ||
        true
    )"

    package_name="$(
        printf '%s\n' "$activity_output" |
            sed -nE \
                '/mResumedActivity|topResumedActivity|ResumedActivity/ {
                    s#.* ([A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+)/[^ ]+.*#\1#
                    t found
                    b
                    :found
                    p
                    q
                }' ||
            true
    )"

    if [[ -n "$package_name" ]]; then
        printf '%s\n' "$package_name"
        return 0
    fi

    window_output="$(
        adb_for_serial \
            "$serial" \
            shell \
            dumpsys \
            window \
            windows \
            2>/dev/null |
            tr -d '\r' ||
        true
    )"

    package_name="$(
        printf '%s\n' "$window_output" |
            sed -nE \
                '/mCurrentFocus|mFocusedApp/ {
                    s#.* ([A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+)/[^ }]+.*#\1#
                    t found
                    b
                    :found
                    p
                    q
                }' ||
            true
    )"

    if [[ -n "$package_name" ]]; then
        printf '%s\n' "$package_name"
        return 0
    fi

    top_output="$(
        adb_for_serial \
            "$serial" \
            shell \
            dumpsys \
            activity \
            top \
            2>/dev/null |
            tr -d '\r' ||
        true
    )"

    package_name="$(
        printf '%s\n' "$top_output" |
            sed -nE \
                's#^[[:space:]]*ACTIVITY[[:space:]]+([A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+)/[^ ]+.*#\1#p' |
            head -n 1 ||
        true
    )"

    if [[ -n "$package_name" ]]; then
        printf '%s\n' "$package_name"
        return 0
    fi

    printf '未知\n'
}

print_device_summary() {
    if (( $# < 2 )); then
        tadk_error \
            "内部错误：print_device_summary 需要 SERIAL 和 STATE"
        return 64
    fi

    local serial="$1"
    local state="$2"
    shift 2

    local details="$*"
    local manufacturer=""
    local model=""
    local android_version=""
    local sdk_version=""
    local foreground_package=""
    local connection_type=""
    local wireless_address=""

    if [[ "$DEVICES_JSON_OUTPUT" == true && "$state" != "device" ]]; then
        _devices_append_json_record \
            "$serial" \
            "$state" \
            "$details" \
            '' \
            '' \
            '' \
            '' \
            '' \
            '' \
            ''
        return 0
    fi

    tadk_separator
    printf '序列号：%s\n' "$serial"
    printf '状态：%s\n' "$state"

    if [[ "$state" != "device" ]]; then
        [[ -z "$details" ]] ||
            printf '详情：%s\n' "$details"

        case "$state" in
            unauthorized)
                printf '处理：请在设备上允许 USB/无线调试授权\n'
                ;;
            offline)
                printf '处理：请重连设备或重启 ADB 服务\n'
                ;;
            *)
                printf '处理：请检查 ADB 连接和设备授权状态\n'
                ;;
        esac

        return 0
    fi

    manufacturer="$(
        device_getprop \
            "$serial" \
            ro.product.manufacturer
    )"

    model="$(
        device_getprop \
            "$serial" \
            ro.product.model
    )"

    android_version="$(
        device_getprop \
            "$serial" \
            ro.build.version.release
    )"

    sdk_version="$(
        device_getprop \
            "$serial" \
            ro.build.version.sdk
    )"

    foreground_package="$(
        device_foreground_package "$serial"
    )"

    if [[ "$DEVICES_JSON_OUTPUT" == true ]]; then
        if [[ "$serial" == *:* ]]; then
            connection_type='wireless'
            wireless_address="$serial"
        else
            connection_type='usb_or_local_adb'
        fi

        if [[ "$foreground_package" == '未知' ]]; then
            foreground_package=''
        fi

        _devices_append_json_record \
            "$serial" \
            "$state" \
            "$details" \
            "${manufacturer:-}" \
            "${model:-}" \
            "${android_version:-}" \
            "${sdk_version:-}" \
            "${foreground_package:-}" \
            "$connection_type" \
            "$wireless_address"
        return 0
    fi

    connection_type="$(
        device_connection_type "$serial"
    )"

    wireless_address="$(
        device_wireless_address "$serial"
    )"

    printf '设备：%s%s\n' \
        "${manufacturer:-未知}" \
        "$(
            if [[ -n "$model" ]]; then
                printf ' %s' "$model"
            fi
        )"

    printf 'Android：%s\n' "${android_version:-未知}"
    printf 'SDK：%s\n' "${sdk_version:-未知}"
    printf '连接：%s\n' "$connection_type"
    printf '无线地址：%s\n' "$wireless_address"
    printf '前台应用：%s\n' "$foreground_package"
}

while (( $# > 0 )); do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --json)
            DEVICES_JSON_OUTPUT=true
            ;;
        *)
            tadk_die "未知参数：$1"
            ;;
    esac

    shift
done

if [[ "$DEVICES_JSON_OUTPUT" == true ]]; then
    if ! tadk_command_exists adb; then
        _devices_print_json_failure 'ADB command not found'
        exit 1
    fi
else
    tadk_adb_require_command
fi

if [[ "$DEVICES_JSON_OUTPUT" == true ]]; then
    if ! devices_output="$(adb devices -l 2>/dev/null)"; then
        _devices_print_json_failure 'adb devices failed'
        exit 1
    fi
else
    devices_output="$(
        adb devices -l
    )"
fi

device_count=0
ready_count=0

if [[ "$DEVICES_JSON_OUTPUT" != true ]]; then
    tadk_heading "TADK Devices"
    printf '\n'
fi

while IFS= read -r line; do
    line="${line%$'\r'}"

    [[ -n "$line" ]] ||
        continue

    [[ "$line" == "List of devices attached"* ]] &&
        continue

    read -r serial state details <<< "$line"

    [[ -n "${serial:-}" ]] ||
        continue

    ((device_count += 1))

    if [[ "${state:-}" == "device" ]]; then
        ((ready_count += 1))
    fi

    print_device_summary \
        "$serial" \
        "${state:-unknown}" \
        "${details:-}"
done <<< "$devices_output"

if [[ "$DEVICES_JSON_OUTPUT" == true ]]; then
    _devices_print_json

    if (( ready_count == 0 )); then
        exit 1
    fi

    exit 0
fi

if (( device_count == 0 )); then
    tadk_warn "未发现 ADB 设备"
    printf '请先启用无线调试并完成 ADB 连接。\n'
    exit 1
fi

tadk_separator
printf '设备总数：%d\n' "$device_count"
printf '可用设备：%d\n' "$ready_count"

if (( ready_count == 0 )); then
    tadk_error "没有已连接并授权的 ADB 设备"
    exit 1
fi
