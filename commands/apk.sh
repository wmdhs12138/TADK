#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"
source "$TADK_ROOT/lib/apk.sh"

BUILD_TYPE="debug"
LIST_ALL=false
PATH_ONLY=false
RELATIVE_PATH=false
SHOW_SIZE=true

usage() {
    cat <<'HELP'
用法：
  tadk apk [选项]

说明：
  查找当前 Android 项目已经生成的 APK。
  不执行构建、安装或启动。

选项：
  --debug            查找 Debug APK（默认）
  --release          查找 Release APK
  --all              列出所有匹配的 APK
  --path-only        只输出 APK 路径
  --relative         使用相对于项目根目录的路径
  --no-size          不显示 APK 文件大小
  -h, --help         显示帮助

示例：
  tadk apk
  tadk apk --release
  tadk apk --all
  tadk apk --all --release
  tadk apk --path-only
  tadk apk --path-only --relative
HELP
}

display_path() {
    local project_root="$1"
    local apk_path="$2"

    if [[ "$RELATIVE_PATH" == true ]]; then
        tadk_apk_relative_path \
            "$project_root" \
            "$apk_path"
    else
        printf '%s\n' "$apk_path"
    fi
}

display_apk_details() {
    local project_root="$1"
    local apk_path="$2"
    local output_path=""
    local apk_size=""
    local detected_type=""

    output_path="$(
        display_path \
            "$project_root" \
            "$apk_path"
    )"

    if [[ "$PATH_ONLY" == true ]]; then
        printf '%s\n' "$output_path"
        return 0
    fi

    detected_type="$(
        tadk_apk_build_type_from_path \
            "$apk_path"
    )"

    printf 'APK：%s\n' "$output_path"
    printf '类型：%s\n' "$detected_type"

    if [[ "$SHOW_SIZE" == true ]]; then
        apk_size="$(tadk_apk_size "$apk_path" || true)"
        printf '大小：%s\n' "${apk_size:-未知}"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            BUILD_TYPE="debug"
            ;;

        --release)
            BUILD_TYPE="release"
            ;;

        --all)
            LIST_ALL=true
            ;;

        --path-only)
            PATH_ONLY=true
            ;;

        --relative)
            RELATIVE_PATH=true
            ;;

        --no-size)
            SHOW_SIZE=false
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            tadk_die "未知参数：$1"
            ;;
    esac

    shift
done

PROJECT_ROOT="$(tadk_require_project_root)"

if [[ "$LIST_ALL" == false ]]; then
    APK_PATH="$(
        tadk_find_latest_apk \
            "$PROJECT_ROOT" \
            "$BUILD_TYPE"
    )" || tadk_die \
        "未找到 $BUILD_TYPE APK，请先执行：tadk build --$BUILD_TYPE"

    if [[ "$PATH_ONLY" == false ]]; then
        tadk_heading "TADK APK"
        tadk_separator
    fi

    display_apk_details \
        "$PROJECT_ROOT" \
        "$APK_PATH"

    if [[ "$PATH_ONLY" == false ]]; then
        tadk_separator
        printf '\n完成。\n'
    fi

    exit 0
fi

APK_COUNT="$(
    tadk_apk_count \
        "$PROJECT_ROOT" \
        "$BUILD_TYPE"
)"

if [[ "$APK_COUNT" -eq 0 ]]; then
    tadk_die \
        "未找到 $BUILD_TYPE APK，请先执行：tadk build --$BUILD_TYPE"
fi

if [[ "$PATH_ONLY" == false ]]; then
    tadk_heading "TADK APK"
    tadk_separator
    printf '项目：%s\n' "$PROJECT_ROOT"
    printf '类型：%s\n' "$BUILD_TYPE"
    printf '数量：%s\n' "$APK_COUNT"
    tadk_separator
    printf '\n'
fi

INDEX=0

while IFS= read -r APK_PATH; do
    [[ -n "$APK_PATH" ]] ||
        continue

    INDEX=$((INDEX + 1))

    if [[ "$PATH_ONLY" == false ]]; then
        printf '[%s]\n' "$INDEX"
    fi

    display_apk_details \
        "$PROJECT_ROOT" \
        "$APK_PATH"

    if [[ "$PATH_ONLY" == false ]]; then
        printf '\n'
    fi
done < <(
    tadk_apk_list \
        "$PROJECT_ROOT" \
        "$BUILD_TYPE"
)

if [[ "$PATH_ONLY" == false ]]; then
    printf '完成。\n'
fi
