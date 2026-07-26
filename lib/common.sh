#!/usr/bin/env bash

# TADK common shell helpers.
#
# This file is intended to be sourced by other scripts.
# Do not enable set -e here because it would affect the caller.

if [[ -n "${TADK_COMMON_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_COMMON_SH_LOADED=1

if [[ -z "${TADK_ROOT:-}" ]]; then
    TADK_ROOT="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

source "$TADK_ROOT/lib/language.sh"

readonly TADK_COLOR_RED=$'\033[31m'
readonly TADK_COLOR_GREEN=$'\033[32m'
readonly TADK_COLOR_YELLOW=$'\033[33m'
readonly TADK_COLOR_CYAN=$'\033[36m'
readonly TADK_COLOR_BOLD=$'\033[1m'
readonly TADK_COLOR_RESET=$'\033[0m'

tadk_die() {
    local message="$(tadk_localize_legacy "$1")"

    printf '%s%s%s%s\n' \
        "$TADK_COLOR_RED" \
        "$(tadk_text 'prefix.error')" \
        "$message" \
        "$TADK_COLOR_RESET" >&2

    exit "${2:-1}"
}

tadk_info() {
    local message="$(tadk_localize_legacy "$1")"

    printf '%s→%s %s\n' \
        "$TADK_COLOR_CYAN" \
        "$TADK_COLOR_RESET" \
        "$message"
}

tadk_success() {
    local message="$(tadk_localize_legacy "$1")"

    printf '%s✓%s %s\n' \
        "$TADK_COLOR_GREEN" \
        "$TADK_COLOR_RESET" \
        "$message"
}

tadk_warn() {
    local message="$(tadk_localize_legacy "$1")"

    printf '%s!%s %s\n' \
        "$TADK_COLOR_YELLOW" \
        "$TADK_COLOR_RESET" \
        "$message"
}

tadk_error() {
    local message="$(tadk_localize_legacy "$1")"

    printf '%s✗%s %s\n' \
        "$TADK_COLOR_RED" \
        "$TADK_COLOR_RESET" \
        "$message" >&2
}

tadk_heading() {
    local heading="$(tadk_localize_legacy "$1")"

    printf '\n%s%s%s\n' \
        "$TADK_COLOR_BOLD" \
        "$heading" \
        "$TADK_COLOR_RESET"
}

tadk_separator() {
    printf '%s\n' '========================================'
}

tadk_thin_separator() {
    printf '%s\n' '----------------------------------------'
}

tadk_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

tadk_require_command() {
    local command_name="$1"
    local install_hint="${2:-}"

    if tadk_command_exists "$command_name"; then
        return 0
    fi

    if [[ -n "$install_hint" ]]; then
        tadk_die "未找到命令：$command_name。$install_hint"
    else
        tadk_die "未找到命令：$command_name"
    fi
}

tadk_human_size() {
    local path="$1"

    if [[ -e "$path" ]]; then
        du -sh -- "$path" 2>/dev/null |
            awk '{print $1}'
    else
        printf '0'
    fi
}

tadk_size_kb() {
    local path="$1"

    if [[ -e "$path" ]]; then
        du -sk -- "$path" 2>/dev/null |
            awk '{print $1}'
    else
        printf '0'
    fi
}

tadk_format_kb() {
    local kb="${1:-0}"

    awk -v kb="$kb" '
        BEGIN {
            if (kb >= 1048576) {
                printf "%.2f GB", kb / 1048576
            } else if (kb >= 1024) {
                printf "%.2f MB", kb / 1024
            } else {
                printf "%d KB", kb
            }
        }
    '
}

tadk_absolute_path() {
    local path="$1"

    if tadk_command_exists realpath; then
        realpath "$path"
    else
        (
            cd "$(dirname "$path")" &&
                printf '%s/%s\n' "$PWD" "$(basename "$path")"
        )
    fi
}

tadk_expand_home() {
    local path="$1"

    case "$path" in
        "$HOME")
            printf '~\n'
            ;;

        "$HOME"/*)
            printf '~/%s\n' "${path#"$HOME"/}"
            ;;

        *)
            printf '%s\n' "$path"
            ;;
    esac
}
