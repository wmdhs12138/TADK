#!/usr/bin/env bash

# TADK project configuration writer.
#
# Configuration updates are validated before writing and installed
# atomically through a temporary file in the configuration directory.
#
# This file is intended to be sourced by commands.
# Do not enable set -e here because it would affect the caller.
#
# Dependencies:
#   lib/config.sh
#
# Public API:
#   tadk_config_write PROJECT_ROOT MODULE VARIANT
#   tadk_config_set PROJECT_ROOT KEY VALUE
#
# Exit codes:
#   0   configuration written successfully
#   1   configuration is absent for a set operation
#   64  invalid function arguments
#   65  invalid configuration data
#   73  configuration cannot be written

if [[ -n "${TADK_CONFIG_WRITE_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_CONFIG_WRITE_SH_LOADED=1

_config_write_error() {
    printf 'config: %s\n' "$1" >&2
}

_config_write_require_reader() {
    if ! declare -F tadk_config_path >/dev/null 2>&1 ||
       ! declare -F tadk_config_load >/dev/null 2>&1 ||
       ! declare -F _config_validate_module >/dev/null 2>&1 ||
       ! declare -F _config_validate_variant >/dev/null 2>&1; then
        _config_write_error \
            'lib/config.sh must be sourced before lib/config-write.sh'
        return 64
    fi
}

_config_write_validate_values() {
    if (( $# != 2 )); then
        _config_write_error \
            'internal error: _config_write_validate_values requires MODULE VARIANT'
        return 64
    fi

    local module="$1"
    local variant="$2"

    if ! _config_validate_module "$module"; then
        _config_write_error "invalid module '$module'"
        return 65
    fi

    if ! _config_validate_variant "$variant"; then
        _config_write_error "invalid variant '$variant'"
        return 65
    fi
}

_config_write_atomic() {
    if (( $# != 3 )); then
        _config_write_error \
            'internal error: _config_write_atomic requires PATH MODULE VARIANT'
        return 64
    fi

    local config_path="$1"
    local module="$2"
    local variant="$3"
    local config_dir
    local temporary_path

    config_dir="$(dirname -- "$config_path")"

    if ! mkdir -p "$config_dir"; then
        _config_write_error \
            "cannot create configuration directory: $config_dir"
        return 73
    fi

    temporary_path="$config_dir/.project.conf.tmp.$$"

    if ! {
        printf 'version=%s\n' "$TADK_CONFIG_SUPPORTED_VERSION"
        printf 'module=%s\n' "$module"
        printf 'variant=%s\n' "$variant"
    } > "$temporary_path"; then
        rm -f -- "$temporary_path"
        _config_write_error \
            "cannot write temporary configuration: $temporary_path"
        return 73
    fi

    if ! mv -f -- "$temporary_path" "$config_path"; then
        rm -f -- "$temporary_path"
        _config_write_error \
            "cannot install configuration: $config_path"
        return 73
    fi
}

tadk_config_write() {
    if (( $# != 3 )); then
        _config_write_error \
            'usage: tadk_config_write PROJECT_ROOT MODULE VARIANT'
        return 64
    fi

    local project_root="$1"
    local module="$2"
    local variant="$3"
    local config_path

    _config_write_require_reader ||
        return $?

    if [[ -z "$project_root" ]]; then
        _config_write_error 'PROJECT_ROOT must not be empty'
        return 64
    fi

    _config_write_validate_values "$module" "$variant" ||
        return $?

    config_path="$(tadk_config_path "$project_root")" ||
        return $?

    _config_write_atomic \
        "$config_path" \
        "$module" \
        "$variant" ||
        return $?

    local load_status=0

    if tadk_config_load "$project_root"; then
        :
    else
        load_status=$?

        _config_write_error \
            "written configuration failed validation: $config_path"
        return "$load_status"
    fi
}

tadk_config_set() {
    if (( $# != 3 )); then
        _config_write_error \
            'usage: tadk_config_set PROJECT_ROOT KEY VALUE'
        return 64
    fi

    local project_root="$1"
    local key="$2"
    local value="$3"
    local load_status=0
    local module
    local variant

    _config_write_require_reader ||
        return $?

    if [[ -z "$project_root" ]]; then
        _config_write_error 'PROJECT_ROOT must not be empty'
        return 64
    fi

    if tadk_config_load "$project_root"; then
        :
    else
        load_status=$?

        if (( load_status == 1 )); then
            _config_write_error \
                "project configuration does not exist: $(tadk_config_path "$project_root")"
        fi

        return "$load_status"
    fi

    module="$TADK_CONFIG_MODULE"
    variant="$TADK_CONFIG_VARIANT"

    case "$key" in
        module)
            module="$value"
            ;;

        variant)
            variant="$value"
            ;;

        *)
            _config_write_error \
                "unsupported configuration key '$key'"
            return 64
            ;;
    esac

    tadk_config_write \
        "$project_root" \
        "$module" \
        "$variant"
}
