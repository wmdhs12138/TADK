#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"
source "$TADK_ROOT/lib/config.sh"
source "$TADK_ROOT/lib/apk.sh"
source "$TADK_ROOT/lib/adb.sh"

BUILD_TYPE="debug"
BUILD_TYPE_EXPLICIT=false
APK_PATH=""
DEVICE_SERIAL=""
ALLOW_DOWNGRADE=false
GRANT_PERMISSIONS=false
REINSTALL=true
ADB_EXTRA_ARGS=()

PROJECT_ROOT=""
PROJECT_MODULE=""
CONFIG_LOADED=false
RESOLVED_APK_PATH=""

usage() {
    cat <<'HELP'
用法：
  tadk install [选项] [APK路径]

说明：
  安装已有 APK，不执行构建，也不自动启动应用。

  未指定 APK 路径时，如果项目存在 .tadk/project.conf，将从配置的
  module 中查找 APK，并默认使用配置的 variant。

选项：
  --debug            安装最新 Debug APK
  --release          安装最新 Release APK
  --apk PATH         安装指定 APK
  --device SERIAL    指定 ADB 目标设备
  --no-reinstall     不使用 -r 覆盖安装
  --downgrade        允许版本降级，对应 adb install -d
  --grant            自动授予运行时权限，对应 adb install -g
  --                  将后续参数直接传递给 adb install
  -h, --help         显示帮助

优先级：
  指定 APK 路径
      > 配置模块

  --debug / --release
      > project.conf 中的 variant
      > 默认 debug

示例：
  tadk install
  tadk install --release
  tadk install ./app/build/outputs/apk/debug/app-debug.apk
  tadk install --apk ./my-app.apk
  tadk install --device 172.19.0.1:39439
  tadk install --downgrade --grant
  tadk install -- --user 0
HELP
}

resolve_explicit_apk() {
    tadk_apk_resolve \
        "$PWD" \
        "$BUILD_TYPE" \
        "$APK_PATH"
}

resolve_project_apk() {
    local config_status=0
    local resolved_path=""

    PROJECT_ROOT="$(tadk_require_project_root)"

    if tadk_config_load "$PROJECT_ROOT"; then
        CONFIG_LOADED=true
        PROJECT_MODULE="$TADK_CONFIG_MODULE"

        if [[ "$BUILD_TYPE_EXPLICIT" != true ]]; then
            BUILD_TYPE="$TADK_CONFIG_VARIANT"
        fi
    else
        config_status=$?

        if (( config_status != 1 )); then
            tadk_die \
                "无法加载项目配置，状态码：$config_status"
        fi
    fi

    if [[ "$CONFIG_LOADED" == true ]]; then
        if [[ ! -d "$PROJECT_ROOT/$PROJECT_MODULE" ]]; then
            tadk_die \
                "配置的模块目录不存在：$PROJECT_ROOT/$PROJECT_MODULE"
        fi

        resolved_path="$(
            tadk_apk_resolve_module \
                "$PROJECT_ROOT" \
                "$PROJECT_MODULE" \
                "$BUILD_TYPE"
        )" || return $?
    else
        resolved_path="$(
            tadk_apk_resolve \
                "$PROJECT_ROOT" \
                "$BUILD_TYPE"
        )" || return $?
    fi

    RESOLVED_APK_PATH="$resolved_path"
}

while (( $# > 0 )); do
    case "$1" in
        --debug)
            BUILD_TYPE="debug"
            BUILD_TYPE_EXPLICIT=true
            ;;

        --release)
            BUILD_TYPE="release"
            BUILD_TYPE_EXPLICIT=true
            ;;

        --apk)
            shift

            (( $# > 0 )) ||
                tadk_die "--apk 缺少路径参数"

            APK_PATH="$1"
            ;;

        --apk=*)
            APK_PATH="${1#--apk=}"

            [[ -n "$APK_PATH" ]] ||
                tadk_die "--apk 缺少路径参数"
            ;;

        --device)
            shift

            (( $# > 0 )) ||
                tadk_die "--device 缺少设备序列号"

            DEVICE_SERIAL="$1"
            ;;

        --device=*)
            DEVICE_SERIAL="${1#--device=}"

            [[ -n "$DEVICE_SERIAL" ]] ||
                tadk_die "--device 缺少设备序列号"
            ;;

        --no-reinstall)
            REINSTALL=false
            ;;

        --downgrade)
            ALLOW_DOWNGRADE=true
            ;;

        --grant)
            GRANT_PERMISSIONS=true
            ;;

        --)
            shift

            while (( $# > 0 )); do
                ADB_EXTRA_ARGS+=("$1")
                shift
            done

            break
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        -*)
            tadk_die "未知参数：$1"
            ;;

        *)
            if [[ -n "$APK_PATH" ]]; then
                tadk_die "只能指定一个 APK 文件"
            fi

            APK_PATH="$1"
            ;;
    esac

    shift
done

if [[ -n "$DEVICE_SERIAL" ]]; then
    tadk_adb_set_serial "$DEVICE_SERIAL"
fi

if [[ -n "$APK_PATH" ]]; then
    RESOLVED_APK_PATH="$(resolve_explicit_apk)" ||
        tadk_die "APK 不存在或不是有效的 APK 文件：$APK_PATH"
else
    resolve_project_apk ||
        tadk_die "未找到 $BUILD_TYPE APK，请先执行：tadk build"
fi

[[ -f "$RESOLVED_APK_PATH" ]] ||
    tadk_die "APK 不存在：$RESOLVED_APK_PATH"

APK_SIZE="$(tadk_apk_size "$RESOLVED_APK_PATH" || true)"

INSTALL_ARGS=()

if [[ "$REINSTALL" == true ]]; then
    INSTALL_ARGS+=(-r)
fi

if [[ "$ALLOW_DOWNGRADE" == true ]]; then
    INSTALL_ARGS+=(-d)
fi

if [[ "$GRANT_PERMISSIONS" == true ]]; then
    INSTALL_ARGS+=(-g)
fi

INSTALL_ARGS+=("${ADB_EXTRA_ARGS[@]}")

tadk_heading "TADK Install"
tadk_separator
printf 'APK：%s\n' "$RESOLVED_APK_PATH"
printf '大小：%s\n' "${APK_SIZE:-未知}"
printf '类型：%s\n' "$BUILD_TYPE"
printf '目标设备：%s\n' "${DEVICE_SERIAL:-ADB 默认设备}"

if [[ -n "$APK_PATH" ]]; then
    printf '来源：显式 APK 路径\n'
elif [[ "$CONFIG_LOADED" == true ]]; then
    printf '配置：%s\n' "$PROJECT_ROOT/.tadk/project.conf"
    printf '模块：%s\n' "$PROJECT_MODULE"
else
    printf '配置：未找到，使用兼容模式\n'
fi

printf '覆盖安装：%s\n' "$REINSTALL"
printf '允许降级：%s\n' "$ALLOW_DOWNGRADE"
printf '自动授权：%s\n' "$GRANT_PERMISSIONS"

if (( ${#INSTALL_ARGS[@]} > 0 )); then
    printf 'ADB 参数：'
    printf '%q ' "${INSTALL_ARGS[@]}"
    printf '\n'
fi

tadk_separator
printf '\n'

tadk_adb_require_device

tadk_info "开始安装 APK"

tadk_adb install \
    "${INSTALL_ARGS[@]}" \
    "$RESOLVED_APK_PATH"

printf '\n'
tadk_success "APK 安装成功"
printf '\n完成。\n'
