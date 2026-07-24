#!/data/data/com.termux/files/usr/bin/bash

if [[ -n "${TADK_PROJECT_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_PROJECT_SH_LOADED=1

tadk_find_project_root() {
    local start_dir="${1:-$PWD}"
    local current=""

    if [[ ! -d "$start_dir" ]]; then
        return 1
    fi

    current="$(
        cd "$start_dir" 2>/dev/null &&
            pwd -P
    )" || return 1

    while [[ "$current" != "/" ]]; do
        if [[ -f "$current/gradlew" ]] &&
           {
               [[ -f "$current/settings.gradle.kts" ]] ||
                   [[ -f "$current/settings.gradle" ]]
           }; then
            printf '%s\n' "$current"
            return 0
        fi

        current="$(dirname "$current")"
    done

    return 1
}

tadk_require_project_root() {
    local start_dir="${1:-$PWD}"
    local project_root=""

    project_root="$(tadk_find_project_root "$start_dir")" ||
        tadk_die "当前目录不在有效的 Gradle Android 项目中"

    printf '%s\n' "$project_root"
}

tadk_project_gradlew() {
    local project_root="$1"
    local gradlew="$project_root/gradlew"

    [[ -f "$gradlew" ]] ||
        return 1

    printf '%s\n' "$gradlew"
}

tadk_project_settings_file() {
    local project_root="$1"

    if [[ -f "$project_root/settings.gradle.kts" ]]; then
        printf '%s\n' "$project_root/settings.gradle.kts"
        return 0
    fi

    if [[ -f "$project_root/settings.gradle" ]]; then
        printf '%s\n' "$project_root/settings.gradle"
        return 0
    fi

    return 1
}

tadk_project_build_files() {
    local project_root="$1"

    find "$project_root" \
        -maxdepth 4 \
        -type f \
        \( -name 'build.gradle.kts' -o -name 'build.gradle' \) \
        ! -path '*/build/*' \
        ! -path '*/.gradle/*' \
        2>/dev/null |
        sort
}

tadk_project_build_dirs() {
    local project_root="$1"

    find "$project_root" \
        -type d \
        -name build \
        -prune \
        2>/dev/null |
        sort
}
