#!/usr/bin/env bash

if [[ -n "${TADK_COMMAND_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_COMMAND_SH_LOADED=1

tadk_command_manifest() {
    local tadk_root="$1"
    local manifest="$tadk_root/commands/manifest"

    [[ -f "$manifest" ]] || return 1

    printf '%s\n' "$manifest"
}

tadk_command_is_valid_name() {
    local command_name="$1"

    [[ "$command_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]
}

tadk_command_record() {
    local tadk_root="$1"
    local command_name="$2"
    local manifest=""

    tadk_command_is_valid_name "$command_name" || return 1

    manifest="$(tadk_command_manifest "$tadk_root")" ||
        return 1

    awk -F '|' -v command_name="$command_name" '
        $1 == command_name {
            print
            exit
        }
    ' "$manifest"
}

tadk_command_exists_registered() {
    local tadk_root="$1"
    local command_name="$2"
    local record=""

    record="$(
        tadk_command_record "$tadk_root" "$command_name"
    )"

    [[ -n "$record" ]]
}

tadk_command_description() {
    local tadk_root="$1"
    local command_name="$2"
    local record=""

    record="$(
        tadk_command_record "$tadk_root" "$command_name"
    )" || return 1

    [[ -n "$record" ]] || return 1

    tadk_text "$(printf '%s\n' "$record" | cut -d '|' -f 2)"
}

tadk_command_relative_target() {
    local tadk_root="$1"
    local command_name="$2"
    local record=""

    record="$(
        tadk_command_record "$tadk_root" "$command_name"
    )" || return 1

    [[ -n "$record" ]] || return 1

    printf '%s\n' "$record" |
        cut -d '|' -f 3-
}

tadk_command_target() {
    local tadk_root="$1"
    local command_name="$2"
    local relative_target=""
    local absolute_target=""

    relative_target="$(
        tadk_command_relative_target \
            "$tadk_root" \
            "$command_name"
    )" || return 1

    [[ -n "$relative_target" ]] || return 1

    absolute_target="$tadk_root/$relative_target"

    case "$absolute_target" in
        "$tadk_root"/*)
            ;;
        *)
            return 1
            ;;
    esac

    [[ -f "$absolute_target" ]] || return 1

    printf '%s\n' "$absolute_target"
}

tadk_command_list() {
    local tadk_root="$1"
    local manifest=""

    manifest="$(tadk_command_manifest "$tadk_root")" ||
        return 1

    while IFS='|' read -r command_name description_key relative_target; do
        [[ -n "$command_name" ]] || continue
        [[ "$command_name" == \#* ]] && continue
        printf '  %-12s %s\n' \
            "$command_name" \
            "$(tadk_text "$description_key")"
    done < "$manifest"
}

tadk_command_validate_manifest() {
    local tadk_root="$1"
    local manifest=""
    local line_number=0
    local command_name=""
    local description_key=""
    local relative_target=""
    local failed=0

    manifest="$(tadk_command_manifest "$tadk_root")" || {
        tadk_error "$(tadk_text 'command.manifest.missing')"
        return 1
    }

    while IFS='|' read -r \
        command_name \
        description_key \
        relative_target
    do
        ((line_number += 1))

        [[ -n "$command_name" ]] || continue
        [[ "$command_name" == \#* ]] && continue

        if ! tadk_command_is_valid_name "$command_name"; then
            tadk_error \
                "$(tadk_text 'command.manifest.invalid_name' "$line_number" "$command_name")"
            failed=1
        fi

        if [[ -z "$description_key" ]]; then
            tadk_error \
                "$(tadk_text 'command.manifest.missing_description' "$line_number")"
            failed=1
        elif ! tadk_language_has_key "$description_key"; then
            tadk_error \
                "$(tadk_text 'command.manifest.unknown_description' "$line_number" "$description_key")"
            failed=1
        fi

        if [[ -z "$relative_target" ]]; then
            tadk_error \
                "$(tadk_text 'command.manifest.missing_target' "$line_number")"
            failed=1
        elif [[ ! -f "$tadk_root/$relative_target" ]]; then
            tadk_error \
                "$(tadk_text 'command.manifest.target_missing' "$relative_target")"
            failed=1
        fi
    done < "$manifest"

    (( failed == 0 ))
}
