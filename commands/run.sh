#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"
source "$TADK_ROOT/lib/config.sh"
source "$TADK_ROOT/lib/apk.sh"
source "$TADK_ROOT/lib/build.sh"
source "$TADK_ROOT/lib/adb.sh"
source "$TADK_ROOT/lib/android.sh"
source "$TADK_ROOT/lib/workflow.sh"

BUILD_TYPE="debug"
BUILD_TYPE_EXPLICIT=false
INSTALL_MODE="open"
DEVICE_SERIAL=""
CLEAN_FIRST=false
FOLLOW_LOGCAT=false
GRADLE_EXTRA_ARGS=()

PROJECT_ROOT=""
PROJECT_MODULE=""
CONFIG_LOADED=false
BUILD_TASK=""

BUILD_DURATION=""
APK_PATH=""
APK_SIZE=""
RUN_PACKAGE_NAME=""

usage() {
    tadk_print_help 'help.run'
}

run_open_installer() {
    local apk_path="$1"

    if tadk_command_exists termux-open; then
        tadk_info "$(tadk_text 'status.open_installer')"
        termux-open "$apk_path"
    else
        tadk_warn "$(tadk_text 'status.termux_open_missing')"
        tadk_text 'status.apk_generated' "$apk_path"
        printf '\n'
    fi
}

run_adb_install() {
    local apk_path="$1"

    tadk_info "$(tadk_text 'status.adb_installing')"
    tadk_adb_install_replace "$apk_path"
    tadk_success "$(tadk_text 'status.adb_install_success')"
}

run_resolve_package_name() {
    if (( $# != 2 )); then
        tadk_error \
            "内部错误：run_resolve_package_name 需要 PROJECT_ROOT MODULE"
        return 64
    fi

    local project_root="$1"
    local module="$2"

    if [[ -n "$module" ]]; then
        tadk_android_module_package_name \
            "$project_root" \
            "$module"
        return $?
    fi

    tadk_android_package_name "$project_root"
}

run_adb_launch() {
    if (( $# != 2 )); then
        tadk_error "内部错误：run_adb_launch 需要 PROJECT_ROOT MODULE"
        return 64
    fi

    local project_root="$1"
    local module="$2"

    RUN_PACKAGE_NAME="$(
        run_resolve_package_name \
            "$project_root" \
            "$module" ||
        true
    )"

    if [[ -z "$RUN_PACKAGE_NAME" ]]; then
        if [[ "$FOLLOW_LOGCAT" == true ]]; then
            tadk_error \
                "无法识别 applicationId，不能进入应用日志"
            return 1
        fi

        tadk_warn "无法识别 applicationId，已跳过启动"
        return 0
    fi

    tadk_info "尝试启动 $RUN_PACKAGE_NAME"

    if tadk_adb_launch_package "$RUN_PACKAGE_NAME" >/dev/null; then
        tadk_success "应用已启动"
        return 0
    fi

    if [[ "$FOLLOW_LOGCAT" == true ]]; then
        tadk_error "APK 已安装，但自动启动失败"
        return 1
    fi

    tadk_warn "APK 已安装，但自动启动失败"
}

while (( $# > 0 )); do
    case "$1" in
        --build-only)
            INSTALL_MODE="none"
            ;;

        --install)
            INSTALL_MODE="adb"
            ;;

        --open)
            INSTALL_MODE="open"
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

        --logcat)
            FOLLOW_LOGCAT=true
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

if [[ "$FOLLOW_LOGCAT" == true && "$INSTALL_MODE" != "adb" ]]; then
    tadk_die "--logcat 必须与 --install 同时使用"
fi

if [[ -n "$DEVICE_SERIAL" && "$INSTALL_MODE" != "adb" ]]; then
    tadk_die "--device 只能与 --install 模式同时使用"
fi

if [[ -n "$DEVICE_SERIAL" ]]; then
    tadk_adb_set_serial "$DEVICE_SERIAL"
fi

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

run_should_build_only() {
    [[ "$INSTALL_MODE" == "none" ]]
}

run_should_open_installer() {
    [[ "$INSTALL_MODE" == "open" ]]
}

run_should_adb_install() {
    [[ "$INSTALL_MODE" == "adb" ]]
}

run_should_follow_logcat() {
    [[ "$FOLLOW_LOGCAT" == true ]]
}

run_step_build() {
    BUILD_DURATION="$(
        tadk_build_execute_task \
            "$PROJECT_ROOT" \
            "$BUILD_TYPE" \
            "$CLEAN_FIRST" \
            "$BUILD_TASK" \
            "${GRADLE_EXTRA_ARGS[@]}"
    )"
}

run_step_resolve_apk() {
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
}

run_step_report() {
    printf '\n'
    tadk_success "构建成功，用时 ${BUILD_DURATION}s"
    tadk_success "APK：$APK_PATH"
    tadk_success "大小：${APK_SIZE:-未知}"
}

run_step_build_only() {
    printf '\n'
    tadk_text 'status.only_build'
    printf '\n'
}

run_step_open_installer() {
    printf '\n'
    run_open_installer "$APK_PATH"
}

run_step_adb_install() {
    printf '\n'
    run_adb_install "$APK_PATH"
}

run_step_adb_launch() {
    run_adb_launch \
        "$PROJECT_ROOT" \
        "$PROJECT_MODULE"
}

run_step_logcat() {
    [[ -n "$RUN_PACKAGE_NAME" ]] ||
        tadk_die "无法识别应用包名，不能进入日志"

    printf '\n'
    tadk_info "$(tadk_text 'status.logcat_enter')"

    "$TADK_ROOT/commands/logcat.sh" \
        --package "$RUN_PACKAGE_NAME" \
        --launch
}

run_step_complete() {
    tadk_text 'status.complete'
    printf '\n'
}

workflow_register build run_step_build
workflow_register resolve-apk run_step_resolve_apk
workflow_register report run_step_report

workflow_register_if \
    build-only \
    run_should_build_only \
    run_step_build_only

workflow_register_if \
    open-installer \
    run_should_open_installer \
    run_step_open_installer

workflow_register_if \
    adb-install \
    run_should_adb_install \
    run_step_adb_install

workflow_register_if \
    adb-launch \
    run_should_adb_install \
    run_step_adb_launch

workflow_register_if \
    logcat \
    run_should_follow_logcat \
    run_step_logcat

workflow_register complete run_step_complete

tadk_heading "TADK Run"
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
tadk_label mode "$INSTALL_MODE"
tadk_label target_device "${DEVICE_SERIAL:-$(tadk_text 'value.default_device')}"
tadk_label logcat "$FOLLOW_LOGCAT"
tadk_label clean "$CLEAN_FIRST"

if (( ${#GRADLE_EXTRA_ARGS[@]} > 0 )); then
    tadk_text 'label.arguments'
    printf '%q ' "${GRADLE_EXTRA_ARGS[@]}"
    printf '\n'
fi

tadk_separator
printf '\n'

workflow_run \
    build \
    resolve-apk \
    report \
    build-only \
    open-installer \
    adb-install \
    adb-launch \
    logcat \
    complete
