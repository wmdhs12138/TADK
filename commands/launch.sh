#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"
source "$TADK_ROOT/lib/android.sh"
source "$TADK_ROOT/lib/adb.sh"

PACKAGE_NAME=""
RESTART=false

usage() {
    cat <<'HELP'
用法：
  tadk launch [选项] [应用包名]

说明：
  启动设备上已经安装的 Android 应用。
  不执行构建，也不执行安装。

选项：
  --package NAME     指定应用包名
  --restart          启动前先强制停止应用
  -h, --help         显示帮助

包名解析顺序：
  1. 命令行指定的包名
  2. 当前项目 build.gradle 中的 applicationId
  3. 当前项目 build.gradle 中的 namespace

示例：
  tadk launch
  tadk launch com.example.app
  tadk launch --package com.example.app
  tadk launch --restart
HELP
}

resolve_package_name() {
    local project_root=""

    if [[ -n "$PACKAGE_NAME" ]]; then
        printf '%s\n' "$PACKAGE_NAME"
        return 0
    fi

    project_root="$(tadk_require_project_root)"

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

RESOLVED_PACKAGE_NAME="$(
    resolve_package_name
)" || tadk_die \
    "无法识别应用包名，请使用：tadk launch --package <包名>"

tadk_heading "TADK Launch"
tadk_separator
printf '应用包名：%s\n' "$RESOLVED_PACKAGE_NAME"
printf '重新启动：%s\n' "$RESTART"
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

printf '\n完成。\n'
