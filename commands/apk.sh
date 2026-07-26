#!/usr/bin/env bash

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
    tadk_print_help 'help.apk'
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

    tadk_label apk "$output_path"
    tadk_label type "$detected_type"

    if [[ "$SHOW_SIZE" == true ]]; then
        apk_size="$(tadk_apk_size "$apk_path" || true)"
        tadk_label size "${apk_size:-$(tadk_text 'value.unknown')}"
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
        tadk_text 'status.complete'
        printf '\n'
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
    tadk_label project "$PROJECT_ROOT"
    tadk_label type "$BUILD_TYPE"
    tadk_label count "$APK_COUNT"
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
    tadk_text 'status.complete'
    printf '\n'
fi
