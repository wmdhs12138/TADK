#!/usr/bin/env bash

# TADK project initialization library.
#
# This file is intended to be sourced by commands and tests.
# Do not enable set -e here because it would affect the caller.
#
# Public API:
#   tadk_init_project PROJECT_ROOT FORCE [MODULE]
#   tadk_init_config_path PROJECT_ROOT
#   tadk_init_detect_module PROJECT_ROOT [MODULE]
#
# Exit codes:
#   0   project configuration created
#   1   project validation or configuration creation failed
#   64  invalid arguments

if [[ -n "${TADK_INIT_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_INIT_SH_LOADED=1
readonly TADK_INIT_CONFIG_VERSION=1
readonly TADK_INIT_DEFAULT_VARIANT=debug

_TADK_INIT_MODULE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$_TADK_INIT_MODULE_DIR/module.sh"
unset _TADK_INIT_MODULE_DIR

_init_error() {
    if declare -F tadk_error >/dev/null 2>&1; then
        tadk_error "$1"
    else
        printf 'init: %s\n' "$1" >&2
    fi
}

_init_success() {
    if declare -F tadk_success >/dev/null 2>&1; then
        tadk_success "$1"
    else
        printf 'init: %s\n' "$1"
    fi
}

tadk_init_config_path() {
    if (( $# != 1 )); then
        _init_error \
            'internal error: tadk_init_config_path requires PROJECT_ROOT'
        return 64
    fi

    local project_root="$1"

    if [[ -z "$project_root" ]]; then
        _init_error 'PROJECT_ROOT must not be empty'
        return 64
    fi

    printf '%s\n' "$project_root/.tadk/project.conf"
}

_tadk_init_is_project_root() {
    if (( $# != 1 )); then
        return 64
    fi

    local project_root="$1"

    [[ -d "$project_root" ]] || return 1
    [[ -f "$project_root/gradlew" ]] || return 1

    [[ -f "$project_root/settings.gradle.kts" ]] ||
        [[ -f "$project_root/settings.gradle" ]]
}

_tadk_init_module_has_application_plugin() {
    if (( $# != 1 )); then
        return 64
    fi

    local module_dir="$1"
    local build_file=""

    for build_file in \
        "$module_dir/build.gradle.kts" \
        "$module_dir/build.gradle"
    do
        [[ -f "$build_file" ]] || continue

        grep -qE 'com\.android\.application|android\.application|androidApplication' "$build_file"
        return $?
    done

    return 1
}

tadk_init_detect_module() {
    if (( $# < 1 || $# > 2 )); then
        _init_error \
            'usage: tadk_init_detect_module PROJECT_ROOT [MODULE]'
        return 64
    fi

    local project_root="$1"
    local requested_module="${2:-}"
    local build_file
    local module_dir
    local module_name
    local -a modules=()

    if [[ -z "$project_root" ]]; then
        _init_error 'PROJECT_ROOT must not be empty'
        return 64
    fi

    if [[ -n "$requested_module" ]]; then
        tadk_module_validate "$requested_module" || {
            _init_error "invalid Android application module: $requested_module"
            return 64
        }

        module_dir="$project_root/$requested_module"

        _tadk_init_module_has_application_plugin "$module_dir" || {
            _init_error \
                "module is not an Android application module: $requested_module"
            return 1
        }

        printf '%s\n' "$requested_module"
        return 0
    fi

    if _tadk_init_module_has_application_plugin "$project_root/app"; then
        printf 'app\n'
        return 0
    fi

    while IFS= read -r build_file; do
        module_dir="$(dirname "$build_file")"
        [[ "$module_dir" != "$project_root" ]] || continue
        _tadk_init_module_has_application_plugin "$module_dir" || continue

        module_name="${module_dir#"$project_root"/}"
        tadk_module_validate "$module_name" || continue
        modules+=("$module_name")
    done < <(
        find "$project_root" \
            -type f \
            \( -name 'build.gradle.kts' -o -name 'build.gradle' \) \
            ! -path '*/build/*' \
            ! -path '*/.gradle/*' \
            -print 2>/dev/null |
            sort
    )

    case "${#modules[@]}" in
        0)
            _init_error \
                'no Android application module with a Gradle build file was found'
            return 1
            ;;

        1)
            printf '%s\n' "${modules[0]}"
            return 0
            ;;

        *)
            _init_error \
            'multiple Android application modules were found; automatic selection is ambiguous'
            printf 'init: modules:' >&2

            for module_name in "${modules[@]}"; do
                printf ' %s' "$module_name" >&2
            done

            printf '\n' >&2
            return 1
            ;;
    esac
}

_tadk_init_write_config() {
    if (( $# != 3 )); then
        _init_error \
            'internal error: _tadk_init_write_config requires PATH MODULE VARIANT'
        return 64
    fi

    local config_path="$1"
    local module="$2"
    local variant="$3"
    local config_dir
    local temporary_path

    config_dir="$(dirname "$config_path")"

    mkdir -p "$config_dir" || {
        _init_error "cannot create configuration directory: $config_dir"
        return 1
    }

    temporary_path="$config_dir/.project.conf.tmp.$$"

    if ! {
        printf 'version=%s\n' "$TADK_INIT_CONFIG_VERSION"
        printf 'module=%s\n' "$module"
        printf 'variant=%s\n' "$variant"
    } > "$temporary_path"; then
        rm -f "$temporary_path"
        _init_error "cannot write temporary configuration: $temporary_path"
        return 1
    fi

    if ! mv -f "$temporary_path" "$config_path"; then
        rm -f "$temporary_path"
        _init_error "cannot install configuration: $config_path"
        return 1
    fi
}

tadk_init_project() {
    if (( $# < 2 || $# > 3 )); then
        _init_error 'usage: tadk_init_project PROJECT_ROOT FORCE [MODULE]'
        return 64
    fi

    local project_root="$1"
    local force="$2"
    local requested_module="${3:-}"
    local config_path
    local module

    if [[ -z "$project_root" ]]; then
        _init_error 'PROJECT_ROOT must not be empty'
        return 64
    fi

    case "$force" in
        true|false)
            ;;
        *)
            _init_error 'FORCE must be true or false'
            return 64
            ;;
    esac

    if ! _tadk_init_is_project_root "$project_root"; then
        _init_error \
            "not a valid Gradle Android project root: $project_root"
        return 1
    fi

    config_path="$(tadk_init_config_path "$project_root")" ||
        return $?

    if [[ -e "$config_path" && "$force" != true ]]; then
        _init_error \
            "project configuration already exists: $config_path"
        return 1
    fi

    module="$(
        tadk_init_detect_module \
            "$project_root" \
            "$requested_module"
    )" ||
        return $?

    _tadk_init_write_config \
        "$config_path" \
        "$module" \
        "$TADK_INIT_DEFAULT_VARIANT" ||
        return $?

    _init_success "project configuration created: $config_path"
    printf 'Module: %s\n' "$module"
    printf 'Variant: %s\n' "$TADK_INIT_DEFAULT_VARIANT"
}
