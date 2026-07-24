#!/data/data/com.termux/files/usr/bin/bash

if [[ -n "${TADK_ADB_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_ADB_SH_LOADED=1

tadk_adb_state() {
    if ! tadk_command_exists adb; then
        return 1
    fi

    adb get-state 2>/dev/null
}

tadk_adb_require_command() {
    tadk_require_command adb \
        "请执行：pkg install android-tools"
}

tadk_adb_require_device() {
    local adb_state=""

    tadk_adb_require_command

    adb_state="$(tadk_adb_state || true)"

    if [[ "$adb_state" != "device" ]]; then
        tadk_error "ADB 设备未连接"
        printf '当前状态：%s\n' "${adb_state:-未连接}"
        printf '请先连接无线调试设备。\n'
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

    adb install "$@" "$apk_path"
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

    adb shell pm list packages "$package_name" 2>/dev/null |
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

    adb shell monkey \
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

    adb shell am force-stop "$package_name"
}
