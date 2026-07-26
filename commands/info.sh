#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"
source "$TADK_ROOT/lib/apk.sh"
source "$TADK_ROOT/lib/gradle.sh"
source "$TADK_ROOT/lib/git.sh"

usage() {
    tadk_print_help 'help.info'
}

value_or_unknown() {
    local value="${1:-}"

    if [[ -n "$value" ]]; then
        printf '%s\n' "$value"
    else
        tadk_text 'value.unknown'
        printf '\n'
    fi
}

print_row() {
    local label="$1"
    local value="${2:-$(tadk_text 'value.unknown')}"

    printf '%-18s %s\n' "$(tadk_text "info.row.$label")" "$value"
}

print_section() {
    printf '\n%s%s%s\n' \
        "$TADK_COLOR_BOLD" \
        "$(tadk_text "info.section.$1")" \
        "$TADK_COLOR_RESET"

    tadk_thin_separator
}

format_apk() {
    local project_root="$1"
    local apk_path="$2"

    if [[ -z "$apk_path" || ! -f "$apk_path" ]]; then
        tadk_text 'info.value.not_built'
        printf '\n'
        return 0
    fi

    local relative_path="${apk_path#"$project_root"/}"
    local size=""

    size="$(tadk_apk_size "$apk_path" || true)"

    printf '%s (%s)\n' \
        "$relative_path" \
        "${size:-$(tadk_text 'info.value.unknown_size')}"
}

if [[ $# -gt 0 ]]; then
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;

        *)
            tadk_die "未知参数：$1"
            ;;
    esac
fi

PROJECT_ROOT="$(tadk_require_project_root)"

APP_BUILD_FILE="$(
    tadk_find_android_app_build_file "$PROJECT_ROOT" || true
)"

PROJECT_NAME="$(
    tadk_project_name "$PROJECT_ROOT" || true
)"

NAMESPACE=""
APPLICATION_ID=""
COMPILE_SDK=""
MIN_SDK=""
TARGET_SDK=""
VERSION_CODE=""
VERSION_NAME=""
COMPOSE_ENABLED="$(tadk_text 'value.unknown')"

if [[ -n "$APP_BUILD_FILE" ]]; then
    NAMESPACE="$(
        tadk_android_namespace "$APP_BUILD_FILE" || true
    )"

    APPLICATION_ID="$(
        tadk_android_application_id "$APP_BUILD_FILE" || true
    )"

    COMPILE_SDK="$(
        tadk_android_compile_sdk "$APP_BUILD_FILE" || true
    )"

    MIN_SDK="$(
        tadk_android_min_sdk "$APP_BUILD_FILE" || true
    )"

    TARGET_SDK="$(
        tadk_android_target_sdk "$APP_BUILD_FILE" || true
    )"

    VERSION_CODE="$(
        tadk_android_version_code "$APP_BUILD_FILE" || true
    )"

    VERSION_NAME="$(
        tadk_android_version_name "$APP_BUILD_FILE" || true
    )"

    COMPOSE_ENABLED="$(
        tadk_compose_enabled "$APP_BUILD_FILE"
    )"
fi

GRADLE_VERSION="$(
    tadk_gradle_wrapper_version "$PROJECT_ROOT" || true
)"

AGP_VERSION="$(
    tadk_agp_version "$PROJECT_ROOT" || true
)"

KOTLIN_VERSION="$(
    tadk_kotlin_version "$PROJECT_ROOT" || true
)"

DEBUG_APK="$(
    tadk_find_debug_apk "$PROJECT_ROOT" || true
)"

RELEASE_APK="$(
    tadk_find_release_apk "$PROJECT_ROOT" || true
)"

tadk_heading "TADK Project Info"
tadk_separator

print_section project
print_row name "$(value_or_unknown "$PROJECT_NAME")"
print_row root "$(tadk_expand_home "$PROJECT_ROOT")"
print_row build_file "$(
    if [[ -n "$APP_BUILD_FILE" ]]; then
        printf '%s\n' "${APP_BUILD_FILE#"$PROJECT_ROOT"/}"
    else
        tadk_text 'value.unknown'
        printf '\n'
    fi
)"

print_section android
print_row namespace "$(value_or_unknown "$NAMESPACE")"
print_row application_id "$(value_or_unknown "$APPLICATION_ID")"
print_row compile_sdk "$(value_or_unknown "$COMPILE_SDK")"
print_row min_sdk "$(value_or_unknown "$MIN_SDK")"
print_row target_sdk "$(value_or_unknown "$TARGET_SDK")"
print_row compose "$COMPOSE_ENABLED"

print_section version
print_row version_name "$(value_or_unknown "$VERSION_NAME")"
print_row version_code "$(value_or_unknown "$VERSION_CODE")"

print_section build_tools
print_row gradle "$(value_or_unknown "$GRADLE_VERSION")"
print_row android_gradle "$(value_or_unknown "$AGP_VERSION")"
print_row kotlin "$(value_or_unknown "$KOTLIN_VERSION")"

print_section git

if tadk_git_is_repository "$PROJECT_ROOT"; then
    GIT_BRANCH="$(
        tadk_git_branch "$PROJECT_ROOT" || true
    )"

    GIT_COMMIT="$(
        tadk_git_commit_short "$PROJECT_ROOT" || true
    )"

    GIT_STATUS="$(
        tadk_git_status_text "$PROJECT_ROOT"
    )"

    GIT_CHANGED="$(
        tadk_git_changed_count "$PROJECT_ROOT"
    )"

    print_row branch "$(value_or_unknown "$GIT_BRANCH")"
    print_row commit "$(value_or_unknown "$GIT_COMMIT")"

    if [[ "$GIT_STATUS" == "Clean" ]]; then
        print_row status "$(tadk_text 'info.value.clean')"
    else
        print_row status "$(tadk_text 'info.value.modified' "$GIT_CHANGED")"
    fi
else
    print_row repository "$(tadk_text 'info.value.not_initialized')"
fi

print_section artifacts
print_row debug_apk "$(format_apk "$PROJECT_ROOT" "$DEBUG_APK")"
print_row release_apk "$(format_apk "$PROJECT_ROOT" "$RELEASE_APK")"

printf '\n'
