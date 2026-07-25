#!/data/data/com.termux/files/usr/bin/bash

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
CLEAN_FIRST=false
GRADLE_EXTRA_ARGS=()

PROJECT_ROOT=""
PROJECT_MODULE=""
CONFIG_LOADED=false
BUILD_TASK=""

BUILD_DURATION=""
APK_PATH=""
APK_SIZE=""

usage() {
    cat <<'HELP'
用法：
  tadk run [选项]

说明：
  构建 APK，并根据所选模式打开安装界面、通过 ADB 安装，或仅构建。

  如果项目存在 .tadk/project.conf，将使用其中的 module 和 variant。
  命令行中的 --debug 或 --release 会覆盖配置的 variant。

选项：
  --build-only       只构建 APK，不打开或安装
  --install          使用 adb install -r 安装 APK
  --open             使用 termux-open 打开安装界面（默认）
  --debug            构建 Debug APK
  --release          构建 Release APK
  --clean            构建前先执行 Gradle clean
  --no-cache         禁用 Gradle 构建缓存
  --rerun            强制重新执行所有 Gradle 任务
  --                  将后续参数直接传递给 Gradle
  -h, --help         显示帮助

优先级：
  --debug / --release
      > project.conf 中的 variant
      > 默认 debug

示例：
  tadk run
  tadk run --build-only
  tadk run --install
  tadk run --release --build-only
  tadk run --clean -- --stacktrace
HELP
}

run_open_installer() {
    local apk_path="$1"

    if tadk_command_exists termux-open; then
        tadk_info "打开系统安装界面"
        termux-open "$apk_path"
    else
        tadk_warn "未找到 termux-open"
        printf 'APK 已生成：%s\n' "$apk_path"
    fi
}

run_adb_install() {
    local apk_path="$1"

    tadk_info "通过 ADB 安装 APK"
    tadk_adb_install_replace "$apk_path"
    tadk_success "ADB 安装成功"
}

run_adb_launch() {
    if (( $# != 2 )); then
        tadk_error "内部错误：run_adb_launch 需要 PROJECT_ROOT MODULE"
        return 64
    fi

    local project_root="$1"
    local module="$2"
    local package_name=""

    if [[ -n "$module" ]]; then
        package_name="$(
            tadk_android_module_package_name                 "$project_root"                 "$module" ||
            true
        )"
    else
        package_name="$(
            tadk_android_package_name "$project_root" ||
            true
        )"
    fi

    if [[ -z "$package_name" ]]; then
        tadk_warn "无法识别 applicationId，已跳过启动"
        return 0
    fi

    tadk_info "尝试启动 $package_name"

    if tadk_adb_launch_package "$package_name" >/dev/null; then
        tadk_success "应用已启动"
    else
        tadk_warn "APK 已安装，但自动启动失败"
    fi
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

run_should_build_only() {
    [[ "$INSTALL_MODE" == "none" ]]
}

run_should_open_installer() {
    [[ "$INSTALL_MODE" == "open" ]]
}

run_should_adb_install() {
    [[ "$INSTALL_MODE" == "adb" ]]
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
    printf '\n仅构建模式，未执行安装。\n'
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
    run_adb_launch         "$PROJECT_ROOT"         "$PROJECT_MODULE"
}

run_step_complete() {
    printf '\n完成。\n'
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

workflow_register complete run_step_complete

tadk_heading "TADK Run"
tadk_separator
printf '项目：%s\n' "$PROJECT_ROOT"

if [[ "$CONFIG_LOADED" == true ]]; then
    printf '配置：%s\n' "$PROJECT_ROOT/.tadk/project.conf"
    printf '模块：%s\n' "$PROJECT_MODULE"
else
    printf '配置：未找到，使用兼容模式\n'
fi

printf '类型：%s\n' "$BUILD_TYPE"
printf '任务：%s\n' "$BUILD_TASK"
printf '模式：%s\n' "$INSTALL_MODE"
printf '清理：%s\n' "$CLEAN_FIRST"

if (( ${#GRADLE_EXTRA_ARGS[@]} > 0 )); then
    printf '参数：'
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
    complete
