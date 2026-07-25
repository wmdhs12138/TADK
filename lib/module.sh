#!/usr/bin/env bash

# Shared Android module-path validation.
#
# TADK stores modules as project-relative paths, for example:
#   app
#   feature/chat
#
# Gradle receives the equivalent project path with colon separators:
#   :app
#   :feature:chat

if [[ -n "${TADK_MODULE_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_MODULE_SH_LOADED=1

tadk_module_validate() {
    if (( $# != 1 )); then
        return 64
    fi

    local module="$1"

    [[ "$module" =~ ^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*$ ]] ||
        return 1

    case "$module" in
        .|..|./*|../*|*/.|*/..|*/./*|*/../*)
            return 1
            ;;
    esac
}

tadk_module_to_gradle_path() {
    if (( $# != 1 )); then
        return 64
    fi

    local module="$1"

    tadk_module_validate "$module" ||
        return 1

    printf ':%s\n' "${module//\//:}"
}
