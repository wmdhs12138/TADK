#!/usr/bin/env bash

if [[ -n "${TADK_ANDROID_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_ANDROID_SH_LOADED=1

tadk_android_application_id_from_file() {
    local gradle_file="$1"
    local application_id=""

    [[ -f "$gradle_file" ]] ||
        return 1

    application_id="$(
        sed -nE \
            's/^[[:space:]]*applicationId[[:space:]]*=?[[:space:]]*"([^"]+)".*/\1/p' \
            "$gradle_file" |
        head -n 1
    )"

    if [[ -n "$application_id" ]]; then
        printf '%s\n' "$application_id"
        return 0
    fi

    return 1
}

tadk_android_namespace_from_file() {
    local gradle_file="$1"
    local namespace=""

    [[ -f "$gradle_file" ]] ||
        return 1

    namespace="$(
        sed -nE \
            's/^[[:space:]]*namespace[[:space:]]*=?[[:space:]]*"([^"]+)".*/\1/p' \
            "$gradle_file" |
        head -n 1
    )"

    if [[ -n "$namespace" ]]; then
        printf '%s\n' "$namespace"
        return 0
    fi

    return 1
}

tadk_android_application_id() {
    local project_root="$1"
    local gradle_file=""
    local application_id=""

    while IFS= read -r gradle_file; do
        application_id="$(
            tadk_android_application_id_from_file \
                "$gradle_file" ||
            true
        )"

        if [[ -n "$application_id" ]]; then
            printf '%s\n' "$application_id"
            return 0
        fi
    done < <(tadk_project_build_files "$project_root")

    return 1
}

tadk_android_package_name() {
    local project_root="$1"
    local gradle_file=""
    local package_name=""

    package_name="$(
        tadk_android_application_id "$project_root" ||
        true
    )"

    if [[ -n "$package_name" ]]; then
        printf '%s\n' "$package_name"
        return 0
    fi

    while IFS= read -r gradle_file; do
        package_name="$(
            tadk_android_namespace_from_file \
                "$gradle_file" ||
            true
        )"

        if [[ -n "$package_name" ]]; then
            printf '%s\n' "$package_name"
            return 0
        fi
    done < <(tadk_project_build_files "$project_root")

    return 1
}

tadk_android_module_build_file() {
    if (( $# != 2 )); then
        return 64
    fi

    local project_root="$1"
    local module="$2"
    local module_root="$project_root/$module"

    [[ -d "$module_root" ]] ||
        return 1

    if [[ -f "$module_root/build.gradle.kts" ]]; then
        printf '%s\n' "$module_root/build.gradle.kts"
        return 0
    fi

    if [[ -f "$module_root/build.gradle" ]]; then
        printf '%s\n' "$module_root/build.gradle"
        return 0
    fi

    return 1
}

tadk_android_module_application_id() {
    if (( $# != 2 )); then
        return 64
    fi

    local project_root="$1"
    local module="$2"
    local gradle_file=""

    gradle_file="$(
        tadk_android_module_build_file \
            "$project_root" \
            "$module"
    )" || return $?

    tadk_android_application_id_from_file "$gradle_file"
}

tadk_android_module_namespace() {
    if (( $# != 2 )); then
        return 64
    fi

    local project_root="$1"
    local module="$2"
    local gradle_file=""

    gradle_file="$(
        tadk_android_module_build_file \
            "$project_root" \
            "$module"
    )" || return $?

    tadk_android_namespace_from_file "$gradle_file"
}

tadk_android_module_package_name() {
    if (( $# != 2 )); then
        return 64
    fi

    local project_root="$1"
    local module="$2"
    local package_name=""

    package_name="$(
        tadk_android_module_application_id \
            "$project_root" \
            "$module" ||
        true
    )"

    if [[ -n "$package_name" ]]; then
        printf '%s\n' "$package_name"
        return 0
    fi

    package_name="$(
        tadk_android_module_namespace \
            "$project_root" \
            "$module" ||
        true
    )"

    if [[ -n "$package_name" ]]; then
        printf '%s\n' "$package_name"
        return 0
    fi

    return 1
}
