#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"
source "$TADK_ROOT/lib/config.sh"
source "$TADK_ROOT/lib/apk.sh"
source "$TADK_ROOT/lib/build.sh"

BUILD_TYPE="debug"
BUILD_TYPE_EXPLICIT=false
CLEAN_FIRST=false
GRADLE_EXTRA_ARGS=()

PROJECT_ROOT=""
PROJECT_MODULE=""
CONFIG_LOADED=false
BUILD_TASK=""
APK_PATH=""

usage() {
    tadk_print_help 'help.build'
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

        --clean)
            CLEAN_FIRST=true
            ;;

        --no-cache)
            GRADLE_EXTRA_ARGS+=(--no-build-cache)
            ;;

        --rerun)
            GRADLE_EXTRA_ARGS+=(--rerun-tasks)
            ;;

        --)
            shift

            while (( $# > 0 )); do
                GRADLE_EXTRA_ARGS+=("$1")
                shift
            done

            break
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

config_status=0

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

    BUILD_TASK="$(
        tadk_build_module_task \
            "$PROJECT_MODULE" \
            "$BUILD_TYPE"
    )" || tadk_die "无法确定模块 Gradle 构建任务"
else
    BUILD_TASK="$(tadk_build_task "$BUILD_TYPE")" ||
        tadk_die "无法确定 Gradle 构建任务"
fi

tadk_heading "TADK Build"
tadk_separator
tadk_label project "$PROJECT_ROOT"

if [[ "$CONFIG_LOADED" == true ]]; then
    tadk_label config "$PROJECT_ROOT/.tadk/project.conf"
    tadk_label module "$PROJECT_MODULE"
else
    tadk_text 'state.compatibility_mode'
    printf '\n'
fi

tadk_label type "$BUILD_TYPE"
tadk_label task "$BUILD_TASK"
tadk_label clean "$CLEAN_FIRST"

if (( ${#GRADLE_EXTRA_ARGS[@]} > 0 )); then
    tadk_text 'label.arguments'
    printf '%q ' "${GRADLE_EXTRA_ARGS[@]}"
    printf '\n'
fi

tadk_separator
printf '\n'

BUILD_DURATION="$(
    tadk_build_execute_task \
        "$PROJECT_ROOT" \
        "$BUILD_TYPE" \
        "$CLEAN_FIRST" \
        "$BUILD_TASK" \
        "${GRADLE_EXTRA_ARGS[@]}"
)"

if [[ "$CONFIG_LOADED" == true ]]; then
    APK_PATH="$(
        tadk_apk_resolve_module \
            "$PROJECT_ROOT" \
            "$PROJECT_MODULE" \
            "$BUILD_TYPE"
    )" || tadk_die \
        "构建完成，但未在模块 $PROJECT_MODULE 中找到 $BUILD_TYPE APK"
else
    APK_PATH="$(
        tadk_apk_resolve \
            "$PROJECT_ROOT" \
            "$BUILD_TYPE"
    )" || tadk_die \
        "构建完成，但未找到 $BUILD_TYPE APK"
fi

APK_SIZE="$(tadk_apk_size "$APK_PATH" || true)"

printf '\n'
tadk_success "构建成功，用时 ${BUILD_DURATION}s"
tadk_success "APK：$APK_PATH"
tadk_success "大小：${APK_SIZE:-未知}"
tadk_text 'status.complete'
printf '\n'
