#!/data/data/com.termux/files/usr/bin/bash

# TADK project configuration reader.
#
# Configuration files are parsed as plain data and are never sourced.
#
# Public API:
#   tadk_config_path PROJECT_ROOT
#   tadk_config_load PROJECT_ROOT
#
# Results after a successful tadk_config_load:
#   TADK_CONFIG_VERSION
#   TADK_CONFIG_MODULE
#   TADK_CONFIG_VARIANT
#
# Exit codes:
#   0   configuration loaded successfully
#   1   configuration file does not exist
#   64  invalid function arguments
#   65  invalid configuration data

if [[ -n "${TADK_CONFIG_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_CONFIG_SH_LOADED=1
readonly TADK_CONFIG_SUPPORTED_VERSION=1

_TADK_CONFIG_MODULE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$_TADK_CONFIG_MODULE_DIR/module.sh"
unset _TADK_CONFIG_MODULE_DIR

TADK_CONFIG_VERSION=""
TADK_CONFIG_MODULE=""
TADK_CONFIG_VARIANT=""

_config_error() {
    printf 'config: %s\n' "$1" >&2
}

_config_reset() {
    TADK_CONFIG_VERSION=""
    TADK_CONFIG_MODULE=""
    TADK_CONFIG_VARIANT=""
}

tadk_config_path() {
    if (( $# != 1 )); then
        _config_error \
            'usage: tadk_config_path PROJECT_ROOT'
        return 64
    fi

    local project_root="$1"

    if [[ -z "$project_root" ]]; then
        _config_error 'PROJECT_ROOT must not be empty'
        return 64
    fi

    printf '%s\n' "$project_root/.tadk/project.conf"
}

_config_validate_module() {
    if (( $# != 1 )); then
        return 64
    fi

    local module="$1"

    tadk_module_validate "$module"
}

_config_validate_variant() {
    if (( $# != 1 )); then
        return 64
    fi

    case "$1" in
        debug|release)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

_config_assign_value() {
    if (( $# != 3 )); then
        return 64
    fi

    local key="$1"
    local value="$2"
    local config_file="$3"

    case "$key" in
        version)
            if [[ -n "$TADK_CONFIG_VERSION" ]]; then
                _config_error \
                    "duplicate key 'version': $config_file"
                return 65
            fi

            TADK_CONFIG_VERSION="$value"
            ;;

        module)
            if [[ -n "$TADK_CONFIG_MODULE" ]]; then
                _config_error \
                    "duplicate key 'module': $config_file"
                return 65
            fi

            TADK_CONFIG_MODULE="$value"
            ;;

        variant)
            if [[ -n "$TADK_CONFIG_VARIANT" ]]; then
                _config_error \
                    "duplicate key 'variant': $config_file"
                return 65
            fi

            TADK_CONFIG_VARIANT="$value"
            ;;

        *)
            _config_error \
                "unknown key '$key': $config_file"
            return 65
            ;;
    esac
}

_config_validate_loaded() {
    if (( $# != 1 )); then
        return 64
    fi

    local config_file="$1"

    if [[ -z "$TADK_CONFIG_VERSION" ]]; then
        _config_error \
            "missing required key 'version': $config_file"
        return 65
    fi

    if [[ "$TADK_CONFIG_VERSION" != \
          "$TADK_CONFIG_SUPPORTED_VERSION" ]]; then
        _config_error \
            "unsupported configuration version '$TADK_CONFIG_VERSION': $config_file"
        return 65
    fi

    if [[ -z "$TADK_CONFIG_MODULE" ]]; then
        _config_error \
            "missing required key 'module': $config_file"
        return 65
    fi

    if ! _config_validate_module "$TADK_CONFIG_MODULE"; then
        _config_error \
            "invalid module '$TADK_CONFIG_MODULE': $config_file"
        return 65
    fi

    if [[ -z "$TADK_CONFIG_VARIANT" ]]; then
        _config_error \
            "missing required key 'variant': $config_file"
        return 65
    fi

    if ! _config_validate_variant "$TADK_CONFIG_VARIANT"; then
        _config_error \
            "invalid variant '$TADK_CONFIG_VARIANT': $config_file"
        return 65
    fi
}

tadk_config_load() {
    if (( $# != 1 )); then
        _config_error \
            'usage: tadk_config_load PROJECT_ROOT'
        return 64
    fi

    local project_root="$1"
    local config_file
    local line
    local key
    local value
    local line_number=0

    if [[ -z "$project_root" ]]; then
        _config_error 'PROJECT_ROOT must not be empty'
        return 64
    fi

    config_file="$(tadk_config_path "$project_root")" ||
        return $?

    _config_reset

    if [[ ! -e "$config_file" ]]; then
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        _config_error \
            "configuration path is not a regular file: $config_file"
        return 65
    fi

    if [[ ! -r "$config_file" ]]; then
        _config_error \
            "configuration file is not readable: $config_file"
        return 65
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_number=$((line_number + 1))

        case "$line" in
            '')
                continue
                ;;

            \#*)
                continue
                ;;

            *=*)
                key="${line%%=*}"
                value="${line#*=}"
                ;;

            *)
                _config_error \
                    "invalid line $line_number: $config_file"
                _config_reset
                return 65
                ;;
        esac

        if [[ -z "$key" || -z "$value" ]]; then
            _config_error \
                "invalid line $line_number: $config_file"
            _config_reset
            return 65
        fi

        local assign_status=0

        if _config_assign_value \
            "$key" \
            "$value" \
            "$config_file"; then
            :
        else
            assign_status=$?
            _config_reset
            return "$assign_status"
        fi
    done < "$config_file"

    local validate_status=0

    if _config_validate_loaded "$config_file"; then
        :
    else
        validate_status=$?
        _config_reset
        return "$validate_status"
    fi
}
