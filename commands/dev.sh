#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TADK_BIN="$TADK_ROOT/bin/tadk"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/logcat.sh"
source "$TADK_ROOT/lib/workflow.sh"

BUILD_TYPE=""
BUILD_TYPE_EXPLICIT=false
DEVICE_SERIAL=""
CLEAN_FIRST=false
NO_CACHE=false
RERUN_TASKS=false

CLEAR_LOGCAT=true
RESTART_APP=true
FOLLOW_LOGCAT=true

DUMP_MODE=false
RAW_OUTPUT=false
LOGCAT_LINES=""
LOGCAT_FORMAT="threadtime"

BUILD_EXTRA_ARGS=()
INSTALL_EXTRA_ARGS=()
LOGCAT_EXTRA_ARGS=()

usage() {
    tadk_print_help 'help.dev'
}

require_option_value() {
    local option_name="$1"
    local value="${2:-}"

    [[ -n "$value" ]] ||
        tadk_die "$option_name 缺少参数"
}

while [[ $# -gt 0 ]]; do
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
            NO_CACHE=true
            ;;

        --rerun)
            RERUN_TASKS=true
            ;;

        --device)
            shift
            require_option_value "--device" "${1:-}"
            DEVICE_SERIAL="$1"
            ;;

        --device=*)
            DEVICE_SERIAL="${1#--device=}"
            require_option_value "--device" "$DEVICE_SERIAL"
            ;;

        --no-clear)
            CLEAR_LOGCAT=false
            ;;

        --no-restart)
            RESTART_APP=false
            ;;

        --no-logcat)
            FOLLOW_LOGCAT=false
            ;;

        --dump)
            DUMP_MODE=true
            ;;

        --lines)
            shift
            require_option_value "--lines" "${1:-}"
            LOGCAT_LINES="$1"
            ;;

        --lines=*)
            LOGCAT_LINES="${1#--lines=}"
            require_option_value "--lines" "$LOGCAT_LINES"
            ;;

        --format)
            shift
            require_option_value "--format" "${1:-}"
            LOGCAT_FORMAT="$1"
            ;;

        --format=*)
            LOGCAT_FORMAT="${1#--format=}"
            require_option_value "--format" "$LOGCAT_FORMAT"
            ;;

        --raw-output)
            RAW_OUTPUT=true
            ;;

        --build-arg)
            shift
            require_option_value "--build-arg" "${1:-}"
            BUILD_EXTRA_ARGS+=("$1")
            ;;

        --build-arg=*)
            value="${1#--build-arg=}"
            require_option_value "--build-arg" "$value"
            BUILD_EXTRA_ARGS+=("$value")
            ;;

        --install-arg)
            shift
            require_option_value "--install-arg" "${1:-}"
            INSTALL_EXTRA_ARGS+=("$1")
            ;;

        --install-arg=*)
            value="${1#--install-arg=}"
            require_option_value "--install-arg" "$value"
            INSTALL_EXTRA_ARGS+=("$value")
            ;;

        --logcat-arg)
            shift
            require_option_value "--logcat-arg" "${1:-}"
            LOGCAT_EXTRA_ARGS+=("$1")
            ;;

        --logcat-arg=*)
            value="${1#--logcat-arg=}"
            require_option_value "--logcat-arg" "$value"
            LOGCAT_EXTRA_ARGS+=("$value")
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

if [[ -n "$LOGCAT_LINES" ]]; then
    tadk_logcat_validate_lines "$LOGCAT_LINES" ||
        tadk_die "--lines 必须是大于 0 的整数"

    DUMP_MODE=true
fi

tadk_logcat_validate_format "$LOGCAT_FORMAT" ||
    tadk_die "不支持的日志格式：$LOGCAT_FORMAT"

BUILD_ARGS=()
INSTALL_ARGS=()
LAUNCH_ARGS=()
CLEAR_LOGCAT_ARGS=(--clear-only)
LOGCAT_ARGS=(--format "$LOGCAT_FORMAT")

if [[ "$BUILD_TYPE_EXPLICIT" == true ]]; then
    BUILD_ARGS+=("--$BUILD_TYPE")
    INSTALL_ARGS+=("--$BUILD_TYPE")
fi

if [[ -n "$DEVICE_SERIAL" ]]; then
    INSTALL_ARGS+=(--device "$DEVICE_SERIAL")
    LAUNCH_ARGS+=(--device "$DEVICE_SERIAL")
    CLEAR_LOGCAT_ARGS+=(--device "$DEVICE_SERIAL")
    LOGCAT_ARGS+=(--device "$DEVICE_SERIAL")
fi

if [[ "$CLEAN_FIRST" == true ]]; then
    BUILD_ARGS+=(--clean)
fi

if [[ "$NO_CACHE" == true ]]; then
    BUILD_ARGS+=(--no-cache)
fi

if [[ "$RERUN_TASKS" == true ]]; then
    BUILD_ARGS+=(--rerun)
fi

if (( ${#BUILD_EXTRA_ARGS[@]} > 0 )); then
    BUILD_ARGS+=(-- "${BUILD_EXTRA_ARGS[@]}")
fi

if (( ${#INSTALL_EXTRA_ARGS[@]} > 0 )); then
    INSTALL_ARGS+=(-- "${INSTALL_EXTRA_ARGS[@]}")
fi

if [[ "$RESTART_APP" == true ]]; then
    LAUNCH_ARGS+=(--restart)
fi

if [[ "$DUMP_MODE" == true ]]; then
    LOGCAT_ARGS+=(--dump)
fi

if [[ -n "$LOGCAT_LINES" ]]; then
    LOGCAT_ARGS+=(--lines "$LOGCAT_LINES")
fi

if [[ "$RAW_OUTPUT" == true ]]; then
    LOGCAT_ARGS+=(--raw-output)
fi

if (( ${#LOGCAT_EXTRA_ARGS[@]} > 0 )); then
    LOGCAT_ARGS+=(-- "${LOGCAT_EXTRA_ARGS[@]}")
fi

dev_step_build() {
    printf '\n'
    tadk_heading "步骤 1/5：构建 APK"
    printf '\n'
    "$TADK_BIN" build "${BUILD_ARGS[@]}"
}

dev_step_install() {
    printf '\n'
    tadk_heading "步骤 2/5：安装 APK"
    printf '\n'
    "$TADK_BIN" install "${INSTALL_ARGS[@]}"
}

dev_should_clear_logcat() {
    if [[ "$CLEAR_LOGCAT" == true ]]; then
        return 0
    fi

    printf '\n'
    tadk_info "步骤 3/5：跳过清空日志"
    return 1
}

dev_step_clear_logcat() {
    printf '\n'
    tadk_heading "步骤 3/5：清空旧日志"
    printf '\n'
    "$TADK_BIN" logcat "${CLEAR_LOGCAT_ARGS[@]}"
}

dev_step_launch() {
    printf '\n'
    tadk_heading "步骤 4/5：启动应用"
    printf '\n'
    "$TADK_BIN" launch "${LAUNCH_ARGS[@]}"
}

dev_should_follow_logcat() {
    if [[ "$FOLLOW_LOGCAT" == true ]]; then
        return 0
    fi

    printf '\n'
    tadk_info "步骤 5/5：跳过日志监听"
    printf '\n'
    tadk_success "开发流程完成"
    return 1
}

dev_step_logcat() {
    printf '\n'
    tadk_heading "步骤 5/5：应用日志"
    printf '\n'

    exec "$TADK_BIN" logcat "${LOGCAT_ARGS[@]}"
}

workflow_register build dev_step_build
workflow_register install dev_step_install
workflow_register_if \
    clear-logcat \
    dev_should_clear_logcat \
    dev_step_clear_logcat
workflow_register launch dev_step_launch
workflow_register_if \
    logcat \
    dev_should_follow_logcat \
    dev_step_logcat

tadk_heading "TADK Dev"
tadk_separator
if [[ "$BUILD_TYPE_EXPLICIT" == true ]]; then
    tadk_text 'state.build_type_explicit' "$BUILD_TYPE"
    printf '\n'
else
    tadk_text 'state.build_type_configured'
    printf '\n'
fi

tadk_label target_device "${DEVICE_SERIAL:-$(tadk_text 'value.default_device')}"
tadk_label build_clean "$CLEAN_FIRST"
tadk_label clear_logs "$CLEAR_LOGCAT"
tadk_label restart_app "$RESTART_APP"
tadk_label follow_logs "$FOLLOW_LOGCAT"

if [[ "$FOLLOW_LOGCAT" == true ]]; then
    tadk_label log_format "$LOGCAT_FORMAT"
    tadk_label log_snapshot "$DUMP_MODE"

    if [[ -n "$LOGCAT_LINES" ]]; then
        tadk_label log_lines "$LOGCAT_LINES"
    fi
fi

tadk_separator

workflow_run build install clear-logcat launch logcat
