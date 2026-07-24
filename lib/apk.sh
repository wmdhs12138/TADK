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
