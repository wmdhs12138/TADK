#!/data/data/com.termux/files/usr/bin/bash

if [[ -n "${TADK_APK_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_APK_SH_LOADED=1

tadk_find_latest_apk() {
    local project_root="$1"
    local build_type="${2:-debug}"
    local apk=""

    apk="$(
        find "$project_root" \
            -type f \
            -path "*/build/outputs/apk/$build_type/*.apk" \
            ! -name '*androidTest*.apk' \
            ! -name '*unaligned*.apk' \
            -printf '%T@ %p\n' 2>/dev/null |
            sort -nr |
            head -n 1 |
            cut -d' ' -f2-
    )"

    if [[ -n "$apk" && -f "$apk" ]]; then
        printf '%s\n' "$apk"
        return 0
    fi

    return 1
}

tadk_find_latest_module_apk() {
    if (( $# < 2 || $# > 3 )); then
        return 64
    fi

    local project_root="$1"
    local module="$2"
    local build_type="${3:-debug}"
    local module_root
    local apk=""

    [[ -d "$project_root" ]] || return 1

    case "$module" in
        ''|*[!A-Za-z0-9_.-]*)
            return 1
            ;;
    esac

    tadk_apk_validate_type "$build_type" ||
        return 1

    module_root="$project_root/$module"

    [[ -d "$module_root" ]] || return 1

    apk="$(
        find "$module_root/build/outputs/apk/$build_type" \
            -maxdepth 1 \
            -type f \
            -name '*.apk' \
            ! -name '*androidTest*.apk' \
            ! -name '*unaligned*.apk' \
            -printf '%T@ %p\n' 2>/dev/null |
            sort -nr |
            head -n 1 |
            cut -d' ' -f2-
    )"

    if [[ -n "$apk" && -f "$apk" ]]; then
        printf '%s\n' "$apk"
        return 0
    fi

    return 1
}

tadk_apk_resolve_module() {
    if (( $# < 3 || $# > 4 )); then
        return 64
    fi

    local project_root="$1"
    local module="$2"
    local build_type="$3"
    local requested_path="${4:-}"
    local resolved_path=""

    tadk_apk_validate_type "$build_type" ||
        return 1

    if [[ -n "$requested_path" ]]; then
        resolved_path="$(tadk_absolute_path "$requested_path")" ||
            return 1

        [[ -f "$resolved_path" ]] ||
            return 1

        case "$resolved_path" in
            "$project_root/$module/"*.apk|\
            "$project_root/$module/"*/build/outputs/apk/*/*.apk)
                printf '%s\n' "$resolved_path"
                return 0
                ;;

            *)
                return 1
                ;;
        esac
    fi

    tadk_find_latest_module_apk \
        "$project_root" \
        "$module" \
        "$build_type"
}

tadk_find_debug_apk() {
    tadk_find_latest_apk "$1" debug
}

tadk_find_release_apk() {
    tadk_find_latest_apk "$1" release
}

tadk_apk_size() {
    local apk_path="$1"

    [[ -f "$apk_path" ]] ||
        return 1

    du -h -- "$apk_path" 2>/dev/null |
        awk '{print $1}'
}

tadk_apk_validate_type() {
    local build_type="$1"

    case "$build_type" in
        debug|release)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

tadk_apk_list() {
    local project_root="$1"
    local build_type="${2:-all}"

    [[ -d "$project_root" ]] ||
        return 1

    case "$build_type" in
        debug|release)
            find "$project_root" \
                -type f \
                -path "*/build/outputs/apk/$build_type/*.apk" \
                -print 2>/dev/null |
                sort
            ;;

        all)
            find "$project_root" \
                -type f \
                -path "*/build/outputs/apk/*/*.apk" \
                -print 2>/dev/null |
                sort
            ;;

        *)
            return 1
            ;;
    esac
}

tadk_apk_count() {
    local project_root="$1"
    local build_type="${2:-all}"
    local count=0

    while IFS= read -r _apk_path; do
        count=$((count + 1))
    done < <(tadk_apk_list "$project_root" "$build_type")

    printf '%s\n' "$count"
}

tadk_apk_resolve() {
    local project_root="$1"
    local build_type="$2"
    local requested_path="${3:-}"
    local resolved_path=""

    tadk_apk_validate_type "$build_type" ||
        return 1

    if [[ -n "$requested_path" ]]; then
        resolved_path="$(tadk_absolute_path "$requested_path")" ||
            return 1

        [[ -f "$resolved_path" ]] ||
            return 1

        case "$resolved_path" in
            *.apk)
                printf '%s\n' "$resolved_path"
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    fi

    tadk_find_latest_apk \
        "$project_root" \
        "$build_type"
}

tadk_apk_relative_path() {
    local project_root="$1"
    local apk_path="$2"

    case "$apk_path" in
        "$project_root"/*)
            printf '%s\n' "${apk_path#"$project_root"/}"
            ;;
        *)
            printf '%s\n' "$apk_path"
            ;;
    esac
}

tadk_apk_build_type_from_path() {
    local apk_path="$1"

    case "$apk_path" in
        */build/outputs/apk/debug/*.apk)
            printf '%s\n' "debug"
            ;;
        */build/outputs/apk/release/*.apk)
            printf '%s\n' "release"
            ;;
        *)
            printf '%s\n' "unknown"
            ;;
    esac
}
