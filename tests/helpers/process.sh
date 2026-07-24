#!/data/data/com.termux/files/usr/bin/bash

RUN_STATUS=0

run_bash_errexit() {
    if (( $# < 1 )); then
        printf '%s\n' \
            'run_bash_errexit: 缺少 Bash 脚本内容' >&2
        return 2
    fi

    local script="$1"
    shift

    RUN_STATUS=0

    if bash -c '
        set -e
        script="$1"
        shift
        eval "$script"
    ' bash "$script" "$@"; then
        RUN_STATUS=0
    else
        RUN_STATUS=$?
    fi

    return 0
}
