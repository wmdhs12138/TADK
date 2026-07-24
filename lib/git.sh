#!/data/data/com.termux/files/usr/bin/bash

if [[ -n "${TADK_GIT_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_GIT_SH_LOADED=1

tadk_git_is_repository() {
    local directory="$1"

    git -C "$directory" \
        rev-parse --is-inside-work-tree \
        >/dev/null 2>&1
}

tadk_git_branch() {
    local directory="$1"

    git -C "$directory" \
        branch --show-current \
        2>/dev/null
}

tadk_git_commit_short() {
    local directory="$1"

    git -C "$directory" \
        rev-parse --short HEAD \
        2>/dev/null
}

tadk_git_commit_subject() {
    local directory="$1"

    git -C "$directory" \
        log -1 --pretty=%s \
        2>/dev/null
}

tadk_git_status_text() {
    local directory="$1"
    local status=""

    status="$(
        git -C "$directory" \
            status --porcelain \
            2>/dev/null
    )"

    if [[ -z "$status" ]]; then
        printf 'Clean\n'
    else
        printf 'Modified\n'
    fi
}

tadk_git_changed_count() {
    local directory="$1"

    git -C "$directory" \
        status --porcelain \
        2>/dev/null |
        wc -l |
        tr -d ' '
}
