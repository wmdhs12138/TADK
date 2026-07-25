#!/data/data/com.termux/files/usr/bin/bash

# TADK project initialization library.
#
# This file is intended to be sourced by commands and tests.
# Do not enable set -e here because it would affect the caller.
#
# Public API:
#   tadk_init_project PROJECT_ROOT FORCE
#   tadk_init_config_path PROJECT_ROOT
#   tadk_init_detect_module PROJECT_ROOT
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

_tadk_init_module_has_build_file() {
    if (( $# != 1 )); then
        return 64
    fi

    local module_dir="$1"

    [[ -f "$module_dir/build.gradle.kts" ]] ||
        [[ -f "$module_dir/build.gradle" ]]
}

tadk_init_detect_module() {
    if (( $# != 1 )); then
        _init_error \
            'internal error: tadk_init_detect_module requires PROJECT_ROOT'
        return 64
    fi

    local project_root="$1"
    local candidate
    local module_name
    local -a modules=()

    if [[ -z "$project_root" ]]; then
        _init_error 'PROJECT_ROOT must not be empty'
        return 64
    fi

    if _tadk_init_module_has_build_file "$project_root/app"; then
        printf 'app\n'
        return 0
    fi

    for candidate in "$project_root"/*; do
        [[ -d "$candidate" ]] || continue
        _tadk_init_module_has_build_file "$candidate" || continue

        module_name="${candidate#"$project_root"/}"
        modules+=("$module_name")
    done

    case "${#modules[@]}" in
        0)
            _init_error \
                'no direct Android module with a Gradle build file was found'
            return 1
            ;;

        1)
            printf '%s\n' "${modules[0]}"
            return 0
            ;;

        *)
            _init_error \
                'multiple direct modules were found; automatic selection is ambiguous'
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
    if (( $# != 2 )); then
        _init_error 'usage: tadk_init_project PROJECT_ROOT FORCE'
        return 64
    fi

    local project_root="$1"
    local force="$2"
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

    module="$(tadk_init_detect_module "$project_root")" ||
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
