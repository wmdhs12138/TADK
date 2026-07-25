#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"

DEEP_CLEAN=false
DRY_RUN=false
STATUS_ONLY=false

usage() {
    cat <<'HELP'
用法：
  tadk clean [选项]

选项：
  --deep          同时清理当前项目的 .gradle 缓存
  --status        只显示当前项目构建缓存占用
  --dry-run       显示将删除的内容，不实际删除
  -h, --help      显示帮助
HELP
}

safe_remove() {
    local target="$1"
    local project_root="$2"

    [[ -n "$target" ]] ||
        tadk_die "拒绝删除空路径"

    [[ "$target" != "/" ]] ||
        tadk_die "拒绝删除根目录"

    [[ "$target" != "$HOME" ]] ||
        tadk_die "拒绝删除 HOME 目录"

    case "$target" in
        "$project_root"/*)
            ;;
        *)
            tadk_die "拒绝删除项目目录之外的路径：$target"
            ;;
    esac

    [[ -e "$target" ]] || return 0

    if [[ "$DRY_RUN" == true ]]; then
        printf '  将删除：%s (%s)\n' \
            "$target" \
            "$(tadk_human_size "$target")"
    else
        printf '  删除：%s (%s)\n' \
            "$target" \
            "$(tadk_human_size "$target")"

        rm -rf -- "$target"
    fi
}

show_status() {
    local project_root="$1"
    local total_kb=0
    local current_kb=0
    local build_dir=""

    tadk_heading "项目缓存占用"
    tadk_separator

    while IFS= read -r build_dir; do
        [[ -n "$build_dir" ]] || continue

        current_kb="$(tadk_size_kb "$build_dir")"
        total_kb=$((total_kb + current_kb))

        printf '%-12s %s\n' \
            "$(tadk_format_kb "$current_kb")" \
            "$build_dir"
    done < <(tadk_project_build_dirs "$project_root")

    if [[ -d "$project_root/.gradle" ]]; then
        current_kb="$(
            tadk_size_kb "$project_root/.gradle"
        )"

        total_kb=$((total_kb + current_kb))

        printf '%-12s %s\n' \
            "$(tadk_format_kb "$current_kb")" \
            "$project_root/.gradle"
    fi

    tadk_thin_separator

    printf '%-12s %s\n' \
        "$(tadk_format_kb "$total_kb")" \
        "项目本地缓存总计"

    printf '\n'

    if [[ -d "$HOME/.gradle/caches" ]]; then
        printf '全局 Gradle 缓存：%s\n' \
            "$(tadk_human_size "$HOME/.gradle/caches")"
        printf '该目录不会被 tadk clean 删除。\n'
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --deep)
            DEEP_CLEAN=true
            ;;

        --dry-run)
            DRY_RUN=true
            ;;

        --status)
            STATUS_ONLY=true
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

if [[ "$STATUS_ONLY" == true ]]; then
    show_status "$PROJECT_ROOT"
    exit 0
fi

tadk_heading "TADK Clean"
tadk_separator
printf '项目：%s\n' "$PROJECT_ROOT"

if [[ "$DEEP_CLEAN" == true ]]; then
    printf '模式：深度清理\n'
else
    printf '模式：标准清理\n'
fi

if [[ "$DRY_RUN" == true ]]; then
    printf '执行：预览模式\n'
else
    printf '执行：实际删除\n'
fi

tadk_separator
printf '\n'

TOTAL_BEFORE_KB=0
TARGET_COUNT=0
BUILD_DIR=""

while IFS= read -r BUILD_DIR; do
    [[ -n "$BUILD_DIR" ]] || continue

    CURRENT_KB="$(tadk_size_kb "$BUILD_DIR")"
    TOTAL_BEFORE_KB=$((TOTAL_BEFORE_KB + CURRENT_KB))

    safe_remove "$BUILD_DIR" "$PROJECT_ROOT"
    ((TARGET_COUNT += 1))
done < <(tadk_project_build_dirs "$PROJECT_ROOT")

if [[ "$DEEP_CLEAN" == true ]] &&
   [[ -d "$PROJECT_ROOT/.gradle" ]]; then
    CURRENT_KB="$(
        tadk_size_kb "$PROJECT_ROOT/.gradle"
    )"

    TOTAL_BEFORE_KB=$((TOTAL_BEFORE_KB + CURRENT_KB))

    safe_remove "$PROJECT_ROOT/.gradle" "$PROJECT_ROOT"
    ((TARGET_COUNT += 1))
fi

printf '\n'

if (( TARGET_COUNT == 0 )); then
    tadk_success "没有发现需要清理的项目缓存"
elif [[ "$DRY_RUN" == true ]]; then
    tadk_info "预览完成"
    printf '预计释放：%s\n' \
        "$(tadk_format_kb "$TOTAL_BEFORE_KB")"
else
    tadk_success "清理完成"
    printf '已删除：%d 个目录\n' "$TARGET_COUNT"
    printf '释放约：%s\n' \
        "$(tadk_format_kb "$TOTAL_BEFORE_KB")"
fi

if [[ "$DEEP_CLEAN" == false ]]; then
    printf '\n提示：使用 tadk clean --deep 可清理项目 .gradle 缓存。\n'
fi

if [[ -d "$HOME/.gradle/caches" ]]; then
    printf '全局 Gradle 缓存保留：%s\n' \
        "$(tadk_human_size "$HOME/.gradle/caches")"
fi
