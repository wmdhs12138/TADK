#!/usr/bin/env bash

if [[ -n "${TADK_LOGCAT_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_LOGCAT_SH_LOADED=1

tadk_logcat_validate_format() {
    local format="$1"

    case "$format" in
        brief|process|tag|thread|raw|time|threadtime|long)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

tadk_logcat_validate_lines() {
    local lines="$1"

    [[ "$lines" =~ ^[1-9][0-9]*$ ]]
}

tadk_logcat_build_args() {
    local format="$1"
    local dump_mode="$2"
    local lines="$3"

    printf '%s\0' -v "$format"

    if [[ "$dump_mode" == true ]]; then
        printf '%s\0' -d
    fi

    if [[ -n "$lines" ]]; then
        printf '%s\0' -t "$lines"
    fi
}
