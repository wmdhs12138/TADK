#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/doctor.sh"

usage() {
    tadk_print_help 'help.doctor'
}

JSON_OUTPUT=false
NORMALIZED_ARGS=()

for argument in "$@"; do
    case "$argument" in
        --json)
            JSON_OUTPUT=true
            ;;
        *)
            NORMALIZED_ARGS+=("$argument")
            ;;
    esac
done

set -- "${NORMALIZED_ARGS[@]}"

if (( $# > 1 )); then
    tadk_error "doctor 最多接受一个项目目录参数"
    usage >&2
    exit 64
fi

PROJECT_ROOT="$PWD"

if (( $# == 1 )); then
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;

        -*)
            tadk_error "未知参数：$1"
            usage >&2
            exit 64
            ;;

        *)
            PROJECT_ROOT="$1"
            ;;
    esac
fi

if [[ -d "$PROJECT_ROOT" ]]; then
    PROJECT_ROOT="$(cd -- "$PROJECT_ROOT" && pwd)"
fi

if [[ "$JSON_OUTPUT" == true ]]; then
    doctor_run "$PROJECT_ROOT" json
else
    doctor_run "$PROJECT_ROOT"
fi
