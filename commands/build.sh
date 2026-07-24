#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"
source "$TADK_ROOT/lib/apk.sh"
source "$TADK_ROOT/lib/build.sh"

BUILD_TYPE="debug"
CLEAN_FIRST=false
GRADLE_EXTRA_ARGS=()

usage() {
    cat <<'HELP'
用法：
  tadk build [选项]

选项：
  --debug            构建 Debug APK（默认）
  --release          构建 Release APK
  --clean            构建前先执行 Gradle clean
  --no-cache         禁用 Gradle 构建缓存
  --rerun            强制重新执行所有 Gradle 任务
  --                  将后续参数直接传递给 Gradle
  -h, --help         显示帮助

示例：
  tadk build
  tadk build --release
  tadk build --clean --no-cache
  tadk build -- --stacktrace
HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
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

tadk_heading "TADK Build"
tadk_separator
printf '项目：%s\n' "$PROJECT_ROOT"
printf '类型：%s\n' "$BUILD_TYPE"
printf '任务：%s\n' "$BUILD_TASK"
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
    tadk_find_latest_apk \
        "$PROJECT_ROOT" \
        "$BUILD_TYPE"
)" || tadk_die "构建完成，但未找到 $BUILD_TYPE APK"

APK_SIZE="$(tadk_apk_size "$APK_PATH" || true)"

printf '\n'
tadk_success "构建成功，用时 ${BUILD_DURATION}s"
tadk_success "APK：$APK_PATH"
tadk_success "大小：${APK_SIZE:-未知}"
printf '\n完成。\n'
