#!/usr/bin/env bash

# TADK project initialization library.
#
# This file is intended to be sourced by commands.
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

_tadk_init_version_catalog_has_application_plugin() {
    if (( $# != 2 )); then
        return 64
    fi

    local project_root="$1"
    local alias_path="$2"
    local catalog_path="$project_root/gradle/libs.versions.toml"
    local normalized_alias="${alias_path//./-}"
    local line
    local key
    local plugin_id
    local in_plugins=false
    local double_pattern='^([A-Za-z0-9_-]+)[[:space:]]*=.*id[[:space:]]*=[[:space:]]*"([^"]+)"'
    local single_pattern="^([A-Za-z0-9_-]+)[[:space:]]*=.*id[[:space:]]*=[[:space:]]*'([^']+)'"

    [[ -f "$catalog_path" ]] || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"

        [[ -n "$line" ]] || continue

        if [[ "$line" =~ ^\[plugins\][[:space:]]*$ ]]; then
            in_plugins=true
            continue
        fi

        if [[ "$line" =~ ^\[[^]]+\][[:space:]]*$ ]]; then
            in_plugins=false
            continue
        fi

        [[ "$in_plugins" == true ]] || continue

        if [[ "$line" =~ $double_pattern ]]; then
            key="${BASH_REMATCH[1]}"
            plugin_id="${BASH_REMATCH[2]}"
        elif [[ "$line" =~ $single_pattern ]]; then
            key="${BASH_REMATCH[1]}"
            plugin_id="${BASH_REMATCH[2]}"
        else
            continue
        fi

        if [[ ( "$key" == "$normalized_alias" || "$key" == "$alias_path" ) &&
              "$plugin_id" == 'com.android.application' ]]; then
            return 0
        fi
    done < "$catalog_path"

    return 1
}

_tadk_init_build_file_has_application_plugin() {
    if (( $# != 2 )); then
        return 64
    fi

    local project_root="$1"
    local build_file="$2"
    local line
    local alias_path
    local plugin_id_pattern
    local id_call_double_regex
    local id_call_single_regex
    local id_argument_double_regex
    local id_argument_single_regex
    local apply_plugin_double_regex
    local apply_plugin_single_regex
    local alias_regex='(^|[[:space:]])alias[[:space:]]*\([[:space:]]*libs[.]plugins[.]([A-Za-z0-9_.-]+)'
    local in_block_comment=false
    local -a application_plugin_patterns=(
        'com[.]android[.]application'
        'android[.]application'
        'androidApplication'
    )

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"

        if [[ "$in_block_comment" == true ]]; then
            if [[ "$line" == *'*/'* ]]; then
                line="${line#*'*/'}"
                in_block_comment=false
                line="${line#"${line%%[![:space:]]*}"}"
            else
                continue
            fi
        fi

        if [[ "$line" == '/*'* ]]; then
            if [[ "$line" == *'*/'* ]]; then
                line="${line#*'*/'}"
                line="${line#"${line%%[![:space:]]*}"}"
            else
                in_block_comment=true
                continue
            fi
        fi

        [[ -n "$line" ]] || continue
        [[ "$line" == '//'* || "$line" == '#'* || "$line" == '*'* ]] &&
            continue

        line="${line%%//*}"

        for plugin_id_pattern in "${application_plugin_patterns[@]}"; do
            id_call_double_regex="(^|[[:space:]])id[[:space:]]*\\([[:space:]]*\"$plugin_id_pattern\""
            id_call_single_regex="(^|[[:space:]])id[[:space:]]*\\([[:space:]]*'$plugin_id_pattern'"
            id_argument_double_regex="(^|[[:space:]])id[[:space:]]+\"$plugin_id_pattern\""
            id_argument_single_regex="(^|[[:space:]])id[[:space:]]+'$plugin_id_pattern'"
            apply_plugin_double_regex="(^|[[:space:]])apply[[:space:]]+plugin[[:space:]]*:[[:space:]]*\"$plugin_id_pattern\""
            apply_plugin_single_regex="(^|[[:space:]])apply[[:space:]]+plugin[[:space:]]*:[[:space:]]*'$plugin_id_pattern'"

            if [[ "$line" =~ $id_call_double_regex ||
                  "$line" =~ $id_call_single_regex ||
                  "$line" =~ $id_argument_double_regex ||
                  "$line" =~ $id_argument_single_regex ||
                  "$line" =~ $apply_plugin_double_regex ||
                  "$line" =~ $apply_plugin_single_regex ]]; then
                return 0
            fi
        done

        if [[ "$line" =~ $alias_regex ]]; then
            alias_path="${BASH_REMATCH[2]}"
            _tadk_init_version_catalog_has_application_plugin \
                "$project_root" \
                "$alias_path" &&
                return 0
        fi
    done < "$build_file"

    return 1
}

_tadk_init_module_has_application_plugin() {
    if (( $# != 2 )); then
        return 64
    fi

    local project_root="$1"
    local module_dir="$2"
    local build_file=""

    for build_file in \
        "$module_dir/build.gradle.kts" \
        "$module_dir/build.gradle"
    do
        [[ -f "$build_file" ]] || continue

        _tadk_init_build_file_has_application_plugin \
            "$project_root" \
            "$build_file" &&
            return 0
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

        _tadk_init_module_has_application_plugin \
            "$project_root" \
            "$module_dir" || {
            _init_error \
                "module is not an Android application module: $requested_module"
            return 1
        }

        printf '%s\n' "$requested_module"
        return 0
    fi

    if _tadk_init_module_has_application_plugin \
        "$project_root" \
        "$project_root/app"; then
        printf 'app\n'
        return 0
    fi

    while IFS= read -r build_file; do
        module_dir="$(dirname "$build_file")"
        [[ "$module_dir" != "$project_root" ]] || continue
        _tadk_init_module_has_application_plugin \
            "$project_root" \
            "$module_dir" || continue

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
