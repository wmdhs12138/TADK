#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"
source "$TADK_ROOT/lib/config.sh"
source "$TADK_ROOT/lib/android.sh"
source "$TADK_ROOT/lib/adb.sh"

PACKAGE_NAME=""
DEVICE_SERIAL=""
RESTART=false

usage() {
    tadk_print_help 'help.launch'
}

resolve_package_name() {
    local project_root=""
    local config_status=0

    if [[ -n "$PACKAGE_NAME" ]]; then
        printf '%s\n' "$PACKAGE_NAME"
        return 0
    fi

    project_root="$(tadk_require_project_root)"

    if tadk_config_load "$project_root"; then
        tadk_android_module_package_name \
            "$project_root" \
            "$TADK_CONFIG_MODULE"
        return $?
    else
        config_status=$?
    fi

    if (( config_status != 1 )); then
        tadk_error \
            "无法加载项目配置，状态码：$config_status"
        return "$config_status"
    fi

    tadk_android_package_name "$project_root"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --package)
            shift

            [[ $# -gt 0 ]] ||
                tadk_die "--package 缺少包名参数"

            PACKAGE_NAME="$1"
            ;;

        --package=*)
            PACKAGE_NAME="${1#--package=}"
            ;;

        --device)
            shift

            [[ $# -gt 0 ]] ||
                tadk_die "--device 缺少设备序列号"

            DEVICE_SERIAL="$1"
            ;;

        --device=*)
            DEVICE_SERIAL="${1#--device=}"

            [[ -n "$DEVICE_SERIAL" ]] ||
                tadk_die "--device 缺少设备序列号"
            ;;

        --restart)
            RESTART=true
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        -*)
            tadk_die "未知参数：$1"
            ;;

        *)
            if [[ -n "$PACKAGE_NAME" ]]; then
                tadk_die "只能指定一个应用包名"
            fi

            PACKAGE_NAME="$1"
            ;;
    esac

    shift
done

if [[ -n "$DEVICE_SERIAL" ]]; then
    tadk_adb_set_serial "$DEVICE_SERIAL"
fi

RESOLVED_PACKAGE_NAME="$(
    resolve_package_name
)" || tadk_die \
    "无法识别应用包名，请使用：tadk launch --package <包名>"

tadk_heading "TADK Launch"
tadk_separator
tadk_label package "$RESOLVED_PACKAGE_NAME"
tadk_label target_device "${DEVICE_SERIAL:-$(tadk_text 'value.default_device')}"
tadk_label restart "$RESTART"
tadk_separator
printf '\n'

tadk_adb_require_device

if [[ "$RESTART" == true ]]; then
    tadk_info "停止现有应用进程"

    tadk_adb_force_stop_package \
        "$RESOLVED_PACKAGE_NAME"
fi

tadk_info "启动应用"

if tadk_adb_launch_package \
    "$RESOLVED_PACKAGE_NAME" \
    >/dev/null; then
    tadk_success "应用已启动"
else
    tadk_die "应用启动失败：$RESOLVED_PACKAGE_NAME"
fi

tadk_text 'status.complete'
printf '\n'
