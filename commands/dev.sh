#!/data/data/com.termux/files/usr/bin/bash

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
    cat <<'HELP'
用法：
  tadk dev [选项]

说明：
  执行完整的 Android 日常开发循环：

    构建
      → 安装
      → 清空旧日志
      → 启动应用
      → 监听应用日志

  dev 只负责编排现有原子命令，不重复实现底层逻辑。

构建选项：
  --debug             构建并安装 Debug APK
  --release           构建并安装 Release APK
  --clean             构建前执行 Gradle clean
  --no-cache          禁用 Gradle 构建缓存
  --rerun             强制重新执行 Gradle 任务

运行选项：
  --device SERIAL     指定整条开发流程的 ADB 目标设备
  --no-clear          启动前不清空 Logcat
  --no-restart        不强制停止旧进程
  --no-logcat         启动应用后不读取日志

日志选项：
  --dump              输出当前日志后退出
  --lines NUMBER      只输出最近指定行数后退出
  --format FORMAT     设置 Logcat 格式，默认 threadtime
  --raw-output        Logcat 阶段不显示 TADK 标题

参数透传：
  --build-arg ARG     向 Gradle 传递一个参数
  --install-arg ARG   向 adb install 传递一个参数
  --logcat-arg ARG    向 adb logcat 传递一个参数

其他：
  -h, --help          显示帮助

示例：
  tadk dev
  tadk dev --clean
  tadk dev --device 172.19.0.1:39439
  tadk dev --no-logcat
  tadk dev --lines 200
  tadk dev --dump --format brief
  tadk dev --build-arg=--stacktrace
  tadk dev --logcat-arg='*:W'
HELP
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
    printf '构建类型：%s（命令行指定）\n' "$BUILD_TYPE"
else
    printf '构建类型：由项目配置或默认值决定\n'
fi

printf '目标设备：%s\n' "${DEVICE_SERIAL:-ADB 默认设备}"
printf '构建前清理：%s\n' "$CLEAN_FIRST"
printf '清空旧日志：%s\n' "$CLEAR_LOGCAT"
printf '重新启动应用：%s\n' "$RESTART_APP"
printf '监听日志：%s\n' "$FOLLOW_LOGCAT"

if [[ "$FOLLOW_LOGCAT" == true ]]; then
    printf '日志格式：%s\n' "$LOGCAT_FORMAT"
    printf '日志快照：%s\n' "$DUMP_MODE"

    if [[ -n "$LOGCAT_LINES" ]]; then
        printf '日志行数：%s\n' "$LOGCAT_LINES"
    fi
fi

tadk_separator

workflow_run build install clear-logcat launch logcat
