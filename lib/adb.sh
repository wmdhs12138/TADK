#!/usr/bin/env bash

if [[ -n "${TADK_ADB_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_ADB_SH_LOADED=1

TADK_ADB_SERIAL="${TADK_ADB_SERIAL:-}"

tadk_adb_set_serial() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：tadk_adb_set_serial 需要设备序列号"
        return 64
    fi

    local serial="$1"

    [[ -n "$serial" ]] || {
        tadk_error "ADB 设备序列号不能为空"
        return 64
    }

    TADK_ADB_SERIAL="$serial"
    export TADK_ADB_SERIAL
}

tadk_adb() {
    if [[ -n "$TADK_ADB_SERIAL" ]]; then
        adb -s "$TADK_ADB_SERIAL" "$@"
    else
        adb "$@"
    fi
}

tadk_adb_state() {
    if ! tadk_command_exists adb; then
        return 1
    fi

    tadk_adb get-state 2>/dev/null
}

tadk_adb_require_command() {
    tadk_require_command adb \
        "请执行：pkg install android-tools"
}

tadk_adb_ready_serials() {
    tadk_adb_require_command

    adb devices 2>/dev/null |
        tr -d '\r' |
        sed -nE \
            's/^([^[:space:]]+)[[:space:]]+device([[:space:]].*)?$/\1/p'
}

tadk_adb_select_unique_ready_device() {
    local serial=""
    local -a ready_serials=()

    while IFS= read -r serial; do
        [[ -n "$serial" ]] ||
            continue

        ready_serials+=("$serial")
    done < <(tadk_adb_ready_serials)

    case "${#ready_serials[@]}" in
        0)
            tadk_error "ADB 设备未连接"
            printf '未发现已连接并授权的 ADB 设备。\n'
            printf '请先连接设备并完成调试授权。\n'
            return 1
            ;;

        1)
            tadk_adb_set_serial "${ready_serials[0]}"
            return 0
            ;;

        *)
            tadk_error "检测到多个可用 ADB 设备"

            printf '可用设备：\n'

            for serial in "${ready_serials[@]}"; do
                printf '  %s\n' "$serial"
            done

            printf '\n请使用 --device SERIAL 指定目标设备。\n'
            return 1
            ;;
    esac
}

tadk_adb_require_device() {
    local adb_state=""

    tadk_adb_require_command

    adb_state="$(tadk_adb_state || true)"

    if [[ "$adb_state" == "device" ]]; then
        return 0
    fi

    if [[ -n "$TADK_ADB_SERIAL" ]]; then
        tadk_error "指定的 ADB 设备不可用：$TADK_ADB_SERIAL"
        printf '当前状态：%s\n' "${adb_state:-未连接}"
        printf '请检查设备地址、连接状态和调试授权。\n'
        return 1
    fi

    tadk_adb_select_unique_ready_device ||
        return 1

    adb_state="$(tadk_adb_state || true)"

    if [[ "$adb_state" != "device" ]]; then
        tadk_error "自动选择的 ADB 设备不可用：$TADK_ADB_SERIAL"
        printf '当前状态：%s\n' "${adb_state:-未连接}"
        return 1
    fi
}

tadk_adb_install_apk() {
    local apk_path="$1"
    shift

    [[ -f "$apk_path" ]] ||
        tadk_die "APK 不存在：$apk_path"

    tadk_adb_require_device ||
        return 1

    tadk_adb install "$@" "$apk_path"
}

tadk_adb_install_replace() {
    local apk_path="$1"
    shift

    tadk_adb_install_apk \
        "$apk_path" \
        -r \
        "$@"
}

tadk_adb_package_installed() {
    local package_name="$1"

    tadk_adb_require_device ||
        return 1

    tadk_adb shell pm list packages "$package_name" 2>/dev/null |
        grep -Fxq "package:$package_name"
}

tadk_adb_launch_package() {
    local package_name="$1"

    [[ -n "$package_name" ]] ||
        tadk_die "应用包名不能为空"

    tadk_adb_require_device ||
        return 1

    if ! tadk_adb_package_installed "$package_name"; then
        tadk_error "设备上未安装应用：$package_name"
        return 1
    fi

    tadk_adb shell monkey \
        -p "$package_name" \
        -c android.intent.category.LAUNCHER \
        1
}

tadk_adb_force_stop_package() {
    local package_name="$1"

    [[ -n "$package_name" ]] ||
        tadk_die "应用包名不能为空"

    tadk_adb_require_device ||
        return 1

    tadk_adb shell am force-stop "$package_name"
}

tadk_adb_package_pid() {
    local package_name="$1"
    local package_pid=""

    [[ -n "$package_name" ]] ||
        tadk_die "应用包名不能为空"

    tadk_adb_require_device ||
        return 1

    package_pid="$(
        tadk_adb shell pidof "$package_name" 2>/dev/null |
        tr -d '\r' |
        awk '{print $1}'
    )"

    if [[ -z "$package_pid" ]]; then
        return 1
    fi

    printf '%s\n' "$package_pid"
}

tadk_adb_clear_logcat() {
    tadk_adb_require_device ||
        return 1

    tadk_adb logcat -c
}

tadk_adb_logcat_all() {
    tadk_adb_require_device ||
        return 1

    tadk_adb logcat "$@"
}

tadk_adb_logcat_package() {
    local package_name="$1"
    local package_pid=""

    shift

    package_pid="$(
        tadk_adb_package_pid "$package_name"
    )" || return 1

    tadk_adb logcat \
        --pid="$package_pid" \
        "$@"
}

tadk_adb_logcat_crash() {
    tadk_adb_require_device ||
        return 1

    tadk_adb logcat \
        -b crash \
        "$@"
}
