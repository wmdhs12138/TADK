#!/usr/bin/env bash

if [[ -n "${TADK_GRADLE_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_GRADLE_SH_LOADED=1

tadk_first_match() {
    local pattern="$1"
    shift

    local file=""
    local value=""

    for file in "$@"; do
        [[ -f "$file" ]] || continue

        value="$(
            sed -nE "$pattern" "$file" |
                head -n 1
        )"

        if [[ -n "$value" ]]; then
            printf '%s\n' "$value"
            return 0
        fi
    done

    return 1
}

tadk_project_name() {
    local project_root="$1"
    local settings_file=""

    settings_file="$(
        tadk_project_settings_file "$project_root"
    )" || return 1

    tadk_first_match \
        's/^[[:space:]]*rootProject\.name[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
        "$settings_file"
}

tadk_find_android_app_build_file() {
    local project_root="$1"
    local build_file=""

    for build_file in \
        "$project_root/app/build.gradle.kts" \
        "$project_root/app/build.gradle"
    do
        if [[ -f "$build_file" ]]; then
            printf '%s\n' "$build_file"
            return 0
        fi
    done

    while IFS= read -r build_file; do
        if grep -qE \
            'com\.android\.application|id[[:space:]]*\([[:space:]]*"com\.android\.application"' \
            "$build_file"; then
            printf '%s\n' "$build_file"
            return 0
        fi
    done < <(tadk_project_build_files "$project_root")

    return 1
}

tadk_android_namespace() {
    local build_file="$1"

    tadk_first_match \
        's/^[[:space:]]*namespace[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
        "$build_file"
}

tadk_android_application_id() {
    local build_file="$1"

    tadk_first_match \
        's/^[[:space:]]*applicationId[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
        "$build_file"
}

tadk_android_compile_sdk() {
    local build_file="$1"

    tadk_first_match \
        's/^[[:space:]]*compileSdk[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p' \
        "$build_file"
}

tadk_android_min_sdk() {
    local build_file="$1"

    tadk_first_match \
        's/^[[:space:]]*minSdk[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p' \
        "$build_file"
}

tadk_android_target_sdk() {
    local build_file="$1"

    tadk_first_match \
        's/^[[:space:]]*targetSdk[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p' \
        "$build_file"
}

tadk_android_version_code() {
    local build_file="$1"

    tadk_first_match \
        's/^[[:space:]]*versionCode[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p' \
        "$build_file"
}

tadk_android_version_name() {
    local build_file="$1"

    tadk_first_match \
        's/^[[:space:]]*versionName[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' \
        "$build_file"
}

tadk_compose_enabled() {
    local build_file="$1"

    if grep -qE \
        'compose[[:space:]]*=[[:space:]]*true' \
        "$build_file"; then
        printf 'Yes\n'
    else
        printf 'No\n'
    fi
}

tadk_gradle_wrapper_version() {
    local project_root="$1"
    local properties_file="$project_root/gradle/wrapper/gradle-wrapper.properties"

    [[ -f "$properties_file" ]] || return 1

    sed -nE \
        's@.*gradle-([0-9][0-9A-Za-z._-]*)-(bin|all)\.zip.*@\1@p' \
        "$properties_file" |
        head -n 1
}

tadk_version_catalog_file() {
    local project_root="$1"
    local catalog="$project_root/gradle/libs.versions.toml"

    [[ -f "$catalog" ]] || return 1

    printf '%s\n' "$catalog"
}

tadk_catalog_version() {
    local catalog_file="$1"
    local key="$2"

    [[ -f "$catalog_file" ]] || return 1

    sed -nE \
        "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]+)\".*/\1/p" \
        "$catalog_file" |
        head -n 1
}

tadk_agp_version() {
    local project_root="$1"
    local catalog=""
    local value=""
    local build_file=""

    catalog="$(
        tadk_version_catalog_file "$project_root" || true
    )"

    if [[ -n "$catalog" ]]; then
        for key in agp androidGradlePlugin android_gradle_plugin; do
            value="$(
                tadk_catalog_version "$catalog" "$key" || true
            )"

            if [[ -n "$value" ]]; then
                printf '%s\n' "$value"
                return 0
            fi
        done
    fi

    for build_file in \
        "$project_root/build.gradle.kts" \
        "$project_root/build.gradle"
    do
        [[ -f "$build_file" ]] || continue

        value="$(
            sed -nE \
                's/.*com\.android\.(application|library).*version[[:space:]]*"([^"]+)".*/\2/p' \
                "$build_file" |
                head -n 1
        )"

        if [[ -n "$value" ]]; then
            printf '%s\n' "$value"
            return 0
        fi
    done

    return 1
}

tadk_kotlin_version() {
    local project_root="$1"
    local catalog=""
    local value=""
    local build_file=""

    catalog="$(
        tadk_version_catalog_file "$project_root" || true
    )"

    if [[ -n "$catalog" ]]; then
        for key in kotlin kotlinVersion kotlin_version; do
            value="$(
                tadk_catalog_version "$catalog" "$key" || true
            )"

            if [[ -n "$value" ]]; then
                printf '%s\n' "$value"
                return 0
            fi
        done
    fi

    for build_file in \
        "$project_root/build.gradle.kts" \
        "$project_root/build.gradle"
    do
        [[ -f "$build_file" ]] || continue

        value="$(
            sed -nE \
                's/.*org\.jetbrains\.kotlin\.[^"]*.*version[[:space:]]*"([^"]+)".*/\1/p' \
                "$build_file" |
                head -n 1
        )"

        if [[ -n "$value" ]]; then
            printf '%s\n' "$value"
            return 0
        fi
    done

    return 1
}
