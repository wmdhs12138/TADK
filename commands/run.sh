#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"
source "$TADK_ROOT/lib/apk.sh"
source "$TADK_ROOT/lib/build.sh"
source "$TADK_ROOT/lib/adb.sh"
source "$TADK_ROOT/lib/android.sh"

BUILD_TYPE="debug"
INSTALL_MODE="open"
CLEAN_FIRST=false
GRADLE_EXTRA_ARGS=()

usage() {
    cat <<'HELP'
用法：
  tadk run [选项]

选项：
  --build-only       只构建 APK，不打开或安装
  --install          使用 adb install -r 安装 APK
  --open             使用 termux-open 打开安装界面（默认）
  --debug            构建 Debug APK（默认）
  --release          构建 Release APK
  --clean            构建前先执行 Gradle clean
  --no-cache         禁用 Gradle 构建缓存
  --rerun            强制重新执行所有 Gradle 任务
  --                  将后续参数直接传递给 Gradle
  -h, --help         显示帮助

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
    local project_root="$1"
    local package_name=""

    package_name="$(
        tadk_android_package_name "$project_root" ||
        true
    )"

    if [[ -z "$package_name" ]]; then
        tadk_warn "无法识别 applicationId，已跳过启动"
        return 0
    fi

    tadk_info "尝试启动 $package_name"

    if tadk_adb_launch_package         "$package_name"         >/dev/null; then
        tadk_success "应用已启动"
    else
        tadk_warn "APK 已安装，但自动启动失败"
    fi
}

while [[ $# -gt 0 ]]; do
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
            ;;

        --release)
            BUILD_TYPE="release"
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

            while [[ $# -gt 0 ]]; do
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

BUILD_TASK="$(tadk_build_task "$BUILD_TYPE")" ||
    tadk_die "无法确定构建任务"

tadk_heading "TADK Run"
tadk_separator
printf '项目：%s\n' "$PROJECT_ROOT"
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

BUILD_DURATION="$(
    tadk_build_execute \
        "$PROJECT_ROOT" \
        "$BUILD_TYPE" \
        "$CLEAN_FIRST" \
        "${GRADLE_EXTRA_ARGS[@]}"
)"

APK_PATH="$(
    tadk_apk_resolve \
        "$PROJECT_ROOT" \
        "$BUILD_TYPE"
)" || tadk_die "构建完成，但未找到 $BUILD_TYPE APK"

APK_SIZE="$(tadk_apk_size "$APK_PATH" || true)"

printf '\n'
tadk_success "构建成功，用时 ${BUILD_DURATION}s"
tadk_success "APK：$APK_PATH"
tadk_success "大小：${APK_SIZE:-未知}"

case "$INSTALL_MODE" in
    none)
        printf '\n仅构建模式，未执行安装。\n'
        ;;

    open)
        printf '\n'
        run_open_installer "$APK_PATH"
        ;;

    adb)
        printf '\n'
        run_adb_install "$APK_PATH"
        run_adb_launch "$PROJECT_ROOT"
        ;;

    *)
        tadk_die "未知运行模式：$INSTALL_MODE"
        ;;
esac

printf '\n完成。\n'
