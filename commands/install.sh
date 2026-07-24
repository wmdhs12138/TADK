#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"
source "$TADK_ROOT/lib/apk.sh"
source "$TADK_ROOT/lib/adb.sh"

BUILD_TYPE="debug"
APK_PATH=""
ALLOW_DOWNGRADE=false
GRANT_PERMISSIONS=false
REINSTALL=true
ADB_EXTRA_ARGS=()

usage() {
    cat <<'HELP'
用法：
  tadk install [选项] [APK路径]

说明：
  安装已有 APK，不执行构建，也不自动启动应用。

选项：
  --debug            安装最新 Debug APK（默认）
  --release          安装最新 Release APK
  --apk PATH         安装指定 APK
  --no-reinstall     不使用 -r 覆盖安装
  --downgrade        允许版本降级，对应 adb install -d
  --grant            自动授予运行时权限，对应 adb install -g
  --                  将后续参数直接传递给 adb install
  -h, --help         显示帮助

示例：
  tadk install
  tadk install --release
  tadk install ./app/build/outputs/apk/debug/app-debug.apk
  tadk install --apk ./my-app.apk
  tadk install --downgrade --grant
  tadk install -- --user 0
HELP
}

resolve_apk_path() {
    local project_root=""

    if [[ -n "$APK_PATH" ]]; then
        tadk_absolute_path "$APK_PATH"
        return
    fi

    project_root="$(tadk_require_project_root)"

    tadk_find_latest_apk \
        "$project_root" \
        "$BUILD_TYPE"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            BUILD_TYPE="debug"
            ;;

        --release)
            BUILD_TYPE="release"
            ;;

        --apk)
            shift

            [[ $# -gt 0 ]] ||
                tadk_die "--apk 缺少路径参数"

            APK_PATH="$1"
            ;;

        --apk=*)
            APK_PATH="${1#--apk=}"
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

            while [[ $# -gt 0 ]]; do
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

RESOLVED_APK_PATH="$(resolve_apk_path)" ||
    tadk_die "未找到 $BUILD_TYPE APK，请先执行：tadk build"

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

adb install \
    "${INSTALL_ARGS[@]}" \
    "$RESOLVED_APK_PATH"

printf '\n'
tadk_success "APK 安装成功"
printf '\n完成。\n'
