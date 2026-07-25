#!/data/data/com.termux/files/usr/bin/bash

if [[ -n "${TADK_BUILD_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_BUILD_SH_LOADED=1

tadk_build_validate_type() {
    local build_type="$1"

    case "$build_type" in
        debug|release)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

tadk_build_task() {
    local build_type="$1"

    case "$build_type" in
        debug)
            printf '%s\n' "assembleDebug"
            ;;
        release)
            printf '%s\n' "assembleRelease"
            ;;
        *)
            return 1
            ;;
    esac
}

tadk_build_validate_module() {
    if (( $# != 1 )); then
        return 64
    fi

    local module="$1"

    [[ -n "$module" ]] || return 1

    case "$module" in
        *[!A-Za-z0-9_.-]*)
            return 1
            ;;
    esac
}

tadk_build_module_task() {
    if (( $# != 2 )); then
        return 64
    fi

    local module="$1"
    local build_type="$2"
    local task=""

    tadk_build_validate_module "$module" ||
        return 1

    task="$(tadk_build_task "$build_type")" ||
        return 1

    printf ':%s:%s\n' "$module" "$task"
}

tadk_build_require_gradlew() {
    local project_root="$1"
    local gradlew=""

    gradlew="$(tadk_project_gradlew "$project_root")" ||
        tadk_die "未找到 Gradle Wrapper"

    if [[ ! -x "$gradlew" ]]; then
        chmod +x "$gradlew" ||
            tadk_die "无法为 Gradle Wrapper 添加执行权限"
    fi

    printf '%s\n' "$gradlew"
}

tadk_build_run_clean() {
    local project_root="$1"
    local gradlew="$2"
    shift 2

    (
        cd "$project_root"

        "$gradlew" clean \
            --console=plain \
            "$@"
    )
}

tadk_build_run_task() {
    local project_root="$1"
    local gradlew="$2"
    local build_task="$3"
    shift 3

    (
        cd "$project_root"

        "$gradlew" "$build_task" \
            --console=plain \
            "$@"
    )
}

tadk_build_execute_task() {
    if (( $# < 4 )); then
        return 64
    fi

    local project_root="$1"
    local build_type="$2"
    local clean_first="$3"
    local build_task="$4"
    shift 4

    local gradlew=""
    local start_time=""
    local end_time=""

    tadk_build_validate_type "$build_type" ||
        tadk_die "不支持的构建类型：$build_type"

    [[ -n "$build_task" ]] ||
        tadk_die "Gradle 构建任务不能为空"

    case "$clean_first" in
        true|false)
            ;;
        *)
            tadk_die "无效的清理选项：$clean_first"
            ;;
    esac

    gradlew="$(tadk_build_require_gradlew "$project_root")"

    if [[ "$clean_first" == true ]]; then
        tadk_info "清理项目" >&2

        tadk_build_run_clean \
            "$project_root" \
            "$gradlew" \
            "$@" >&2 ||
            return $?
    fi

    tadk_info "开始构建 $build_type APK" >&2

    start_time="$(date +%s)"

    tadk_build_run_task \
        "$project_root" \
        "$gradlew" \
        "$build_task" \
        "$@" >&2 ||
        return $?

    end_time="$(date +%s)"

    printf '%s\n' "$((end_time - start_time))"
}

tadk_build_execute() {
    if (( $# < 3 )); then
        return 64
    fi

    local project_root="$1"
    local build_type="$2"
    local clean_first="$3"
    shift 3

    local build_task=""

    build_task="$(tadk_build_task "$build_type")" ||
        tadk_die "无法确定 Gradle 构建任务"

    tadk_build_execute_task \
        "$project_root" \
        "$build_type" \
        "$clean_first" \
        "$build_task" \
        "$@"
}
