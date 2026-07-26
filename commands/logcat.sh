#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"
source "$TADK_ROOT/lib/config.sh"
source "$TADK_ROOT/lib/android.sh"
source "$TADK_ROOT/lib/adb.sh"
source "$TADK_ROOT/lib/logcat.sh"

PACKAGE_NAME=""
DEVICE_SERIAL=""
SHOW_ALL=false
CRASH_MODE=false
CLEAR_FIRST=false
CLEAR_ONLY=false
DUMP_MODE=false
RAW_OUTPUT=false
AUTO_LAUNCH=false
RESTART_APP=false
WAIT_FOR_APP=false
FORMAT="threadtime"
LINES=""
EXTRA_ARGS=()

usage() {
    tadk_print_help 'help.logcat'
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

resolve_package_pid() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：resolve_package_pid 需要 PACKAGE_NAME"
        return 64
    fi

    local package_name="$1"
    local package_pid=""
    local attempt=0
    local max_attempts=20

    package_pid="$(
        tadk_adb_package_pid "$package_name" ||
        true
    )"

    if [[ -n "$package_pid" ]]; then
        printf '%s\n' "$package_pid"
        return 0
    fi

    if [[ "$WAIT_FOR_APP" == true ]]; then
        if [[ "$RAW_OUTPUT" == false ]]; then
            tadk_info \
                "等待应用启动：$package_name" \
                >&2
            printf '请在设备上启动应用，按 Ctrl+C 取消。\n' \
                >&2
        fi

        while true; do
            package_pid="$(
                tadk_adb_package_pid "$package_name" ||
                true
            )"

            if [[ -n "$package_pid" ]]; then
                printf '%s\n' "$package_pid"
                return 0
            fi

            sleep 0.25
        done
    fi

    if [[ "$AUTO_LAUNCH" != true ]]; then
        return 1
    fi

    if [[ "$RAW_OUTPUT" == false ]]; then
        tadk_info \
            "应用未运行，正在启动：$package_name" \
            >&2
    fi

    if ! tadk_adb_launch_package "$package_name" >/dev/null; then
        tadk_error "应用启动失败：$package_name"
        return 1
    fi

    while (( attempt < max_attempts )); do
        package_pid="$(
            tadk_adb_package_pid "$package_name" ||
            true
        )"

        if [[ -n "$package_pid" ]]; then
            printf '%s\n' "$package_pid"
            return 0
        fi

        sleep 0.25
        ((attempt += 1))
    done

    tadk_error "等待应用进程超时：$package_name"
    return 1
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

        --all)
            SHOW_ALL=true
            ;;

        --crash)
            CRASH_MODE=true
            DUMP_MODE=true
            ;;

        --clear)
            CLEAR_FIRST=true
            ;;

        --clear-only)
            CLEAR_ONLY=true
            ;;

        --dump)
            DUMP_MODE=true
            ;;

        --lines)
            shift

            [[ $# -gt 0 ]] ||
                tadk_die "--lines 缺少数字参数"

            LINES="$1"
            ;;

        --lines=*)
            LINES="${1#--lines=}"
            ;;

        --format)
            shift

            [[ $# -gt 0 ]] ||
                tadk_die "--format 缺少格式参数"

            FORMAT="$1"
            ;;

        --format=*)
            FORMAT="${1#--format=}"
            ;;

        --launch)
            AUTO_LAUNCH=true
            ;;

        --restart)
            RESTART_APP=true
            AUTO_LAUNCH=true
            ;;

        --wait)
            WAIT_FOR_APP=true
            ;;

        --raw-output)
            RAW_OUTPUT=true
            ;;

        --)
            shift

            while [[ $# -gt 0 ]]; do
                EXTRA_ARGS+=("$1")
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

if [[ -n "$DEVICE_SERIAL" ]]; then
    tadk_adb_set_serial "$DEVICE_SERIAL"
fi

tadk_logcat_validate_format "$FORMAT" ||
    tadk_die "不支持的日志格式：$FORMAT"

if [[ -n "$LINES" ]]; then
    tadk_logcat_validate_lines "$LINES" ||
        tadk_die "--lines 必须是大于 0 的整数"

    DUMP_MODE=true
fi

if [[ "$SHOW_ALL" == true && -n "$PACKAGE_NAME" ]]; then
    tadk_die "--all 不能与 --package 同时使用"
fi

if [[ "$CRASH_MODE" == true && "$SHOW_ALL" == true ]]; then
    tadk_die "--crash 已经读取整个 crash 缓冲区，无需同时使用 --all"
fi

if [[ "$RESTART_APP" == true && "$SHOW_ALL" == true ]]; then
    tadk_die "--restart 不能与 --all 同时使用"
fi

if [[ "$RESTART_APP" == true && "$CRASH_MODE" == true ]]; then
    tadk_die "--restart 不能与 --crash 同时使用"
fi

if [[ "$RESTART_APP" == true && "$CLEAR_ONLY" == true ]]; then
    tadk_die "--restart 不能与 --clear-only 同时使用"
fi

if [[ "$AUTO_LAUNCH" == true &&
      "$RESTART_APP" == false &&
      "$SHOW_ALL" == true ]]; then
    tadk_die "--launch 不能与 --all 同时使用"
fi

if [[ "$AUTO_LAUNCH" == true &&
      "$RESTART_APP" == false &&
      "$CRASH_MODE" == true ]]; then
    tadk_die "--launch 不能与 --crash 同时使用"
fi

if [[ "$AUTO_LAUNCH" == true &&
      "$RESTART_APP" == false &&
      "$CLEAR_ONLY" == true ]]; then
    tadk_die "--launch 不能与 --clear-only 同时使用"
fi

if [[ "$WAIT_FOR_APP" == true && "$AUTO_LAUNCH" == true ]]; then
    tadk_die "--wait 不能与 --launch 或 --restart 同时使用"
fi

if [[ "$WAIT_FOR_APP" == true && "$SHOW_ALL" == true ]]; then
    tadk_die "--wait 不能与 --all 同时使用"
fi

if [[ "$WAIT_FOR_APP" == true && "$CRASH_MODE" == true ]]; then
    tadk_die "--wait 不能与 --crash 同时使用"
fi

if [[ "$WAIT_FOR_APP" == true && "$CLEAR_ONLY" == true ]]; then
    tadk_die "--wait 不能与 --clear-only 同时使用"
fi

tadk_adb_require_device

if [[ "$CLEAR_ONLY" == true ]]; then
    if [[ "$RAW_OUTPUT" == false ]]; then
        tadk_heading "TADK Logcat"
        tadk_separator
        tadk_label action "$(tadk_text 'status.clear_log_buffer')"
        tadk_separator
        printf '\n'
    fi

    tadk_adb_clear_logcat

    if [[ "$RAW_OUTPUT" == false ]]; then
        tadk_success "$(tadk_text 'status.log_buffer_cleared')"
    fi

    exit 0
fi

if [[ "$CLEAR_FIRST" == true && "$RESTART_APP" == false ]]; then
    if [[ "$RAW_OUTPUT" == false ]]; then
        tadk_info "$(tadk_text 'status.clear_log_buffer')"
    fi

    tadk_adb_clear_logcat
fi

LOGCAT_ARGS=(
    -v "$FORMAT"
)

if [[ "$DUMP_MODE" == true ]]; then
    LOGCAT_ARGS+=(-d)
fi

if [[ -n "$LINES" ]]; then
    LOGCAT_ARGS+=(-t "$LINES")
fi

LOGCAT_ARGS+=("${EXTRA_ARGS[@]}")

if [[ "$CRASH_MODE" == true ]]; then
    if [[ "$RAW_OUTPUT" == false ]]; then
        tadk_heading "TADK Logcat"
        tadk_separator
        tadk_text 'state.logcat_crash'
        printf '\n'
        tadk_label format "$FORMAT"
        tadk_label listen false
        tadk_separator
        printf '\n'
    fi

    tadk_adb_logcat_crash \
        "${LOGCAT_ARGS[@]}"

    exit 0
fi

if [[ "$SHOW_ALL" == true ]]; then
    if [[ "$RAW_OUTPUT" == false ]]; then
        tadk_heading "TADK Logcat"
        tadk_separator
        tadk_text 'state.logcat_all'
        printf '\n'
        tadk_label format "$FORMAT"
        tadk_label listen "$([[ "$DUMP_MODE" == true ]] && printf false || printf true)"
        tadk_separator
        printf '\n'
    fi

    tadk_adb_logcat_all \
        "${LOGCAT_ARGS[@]}"

    exit 0
fi

RESOLVED_PACKAGE_NAME="$(
    resolve_package_name
)" || tadk_die \
    "无法识别应用包名，请使用：tadk logcat --package <包名>"

if [[ "$RESTART_APP" == true ]]; then
    if [[ "$RAW_OUTPUT" == false ]]; then
        tadk_info "停止应用：$RESOLVED_PACKAGE_NAME"
    fi

    tadk_adb_force_stop_package \
        "$RESOLVED_PACKAGE_NAME" ||
        tadk_die "无法停止应用：$RESOLVED_PACKAGE_NAME"

    if [[ "$CLEAR_FIRST" == true ]]; then
        if [[ "$RAW_OUTPUT" == false ]]; then
            tadk_info "清空日志缓冲区"
        fi

        tadk_adb_clear_logcat
    fi
fi

PACKAGE_PID="$(
    resolve_package_pid \
        "$RESOLVED_PACKAGE_NAME"
)" || {
    if [[ "$WAIT_FOR_APP" == true ]]; then
        tadk_die \
            "等待应用进程失败：$RESOLVED_PACKAGE_NAME"
    fi

    if [[ "$AUTO_LAUNCH" == true ]]; then
        tadk_die \
            "无法启动或获取应用进程：$RESOLVED_PACKAGE_NAME"
    fi

    tadk_die \
        "应用当前未运行：$RESOLVED_PACKAGE_NAME
请执行：tadk logcat --launch
或先执行：tadk launch"
}

if [[ "$RAW_OUTPUT" == false ]]; then
    tadk_heading "TADK Logcat"
    tadk_separator
    tadk_label package "$RESOLVED_PACKAGE_NAME"
    tadk_label target_device "${DEVICE_SERIAL:-$(tadk_text 'value.default_device')}"
    tadk_label pid "$PACKAGE_PID"
    tadk_label format "$FORMAT"
    tadk_label listen "$([[ "$DUMP_MODE" == true ]] && printf false || printf true)"
    tadk_separator
    printf '\n'

    if [[ "$DUMP_MODE" == false ]]; then
        tadk_text 'status.stop_logcat'
        printf '\n\n'
    fi
fi

tadk_adb logcat \
    --pid="$PACKAGE_PID" \
    "${LOGCAT_ARGS[@]}"
