#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/self_update.sh"

usage() {
    tadk_print_help 'help.self-update'
}

CHECK_ARCHIVE=""
APPLY_ARCHIVE=""
EXPECTED_SHA256=""
BACKUP_DIR=""
MODE=""
JSON_OUTPUT=false

require_option_value() {
    local option="$1"
    local value="${2:-}"

    [[ -n "$value" ]] ||
        usage_error "$option requires a value" 64
}

usage_error() {
    local message="$1"
    local status="${2:-64}"

    if [[ "$JSON_OUTPUT" == true ]]; then
        tadk_self_update_reset
        TADK_SELF_UPDATE_JSON_OUTPUT=true
        TADK_SELF_UPDATE_ARCHIVE_NAME="${APPLY_ARCHIVE:-$CHECK_ARCHIVE}"
        tadk_self_update_record_check 'argument' fail "$message"
        tadk_self_update_print_json
        exit "$status"
    fi

    tadk_die "$message" "$status"
}

while (( $# > 0 )); do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;

        --check)
            require_option_value "$1" "${2:-}"
            if [[ "$MODE" == check ]]; then
                usage_error '--check may only be provided once' 64
            elif [[ "$MODE" == apply ]]; then
                usage_error '--check and --apply are mutually exclusive' 64
            fi
            MODE=check
            CHECK_ARCHIVE="$2"
            shift
            ;;

        --check=*)
            value="${1#--check=}"
            require_option_value '--check' "$value"
            if [[ "$MODE" == check ]]; then
                usage_error '--check may only be provided once' 64
            elif [[ "$MODE" == apply ]]; then
                usage_error '--check and --apply are mutually exclusive' 64
            fi
            MODE=check
            CHECK_ARCHIVE="$value"
            ;;

        --apply)
            require_option_value "$1" "${2:-}"
            if [[ "$MODE" == apply ]]; then
                usage_error '--apply may only be provided once' 64
            elif [[ "$MODE" == check ]]; then
                usage_error '--check and --apply are mutually exclusive' 64
            fi
            MODE=apply
            APPLY_ARCHIVE="$2"
            shift
            ;;

        --apply=*)
            value="${1#--apply=}"
            require_option_value '--apply' "$value"
            if [[ "$MODE" == apply ]]; then
                usage_error '--apply may only be provided once' 64
            elif [[ "$MODE" == check ]]; then
                usage_error '--check and --apply are mutually exclusive' 64
            fi
            MODE=apply
            APPLY_ARCHIVE="$value"
            ;;

        --sha256)
            require_option_value "$1" "${2:-}"
            [[ -z "$EXPECTED_SHA256" ]] ||
                usage_error '--sha256 may only be provided once' 64
            EXPECTED_SHA256="${2,,}"
            shift
            ;;

        --sha256=*)
            value="${1#--sha256=}"
            require_option_value '--sha256' "$value"
            [[ -z "$EXPECTED_SHA256" ]] ||
                usage_error '--sha256 may only be provided once' 64
            EXPECTED_SHA256="${value,,}"
            ;;

        --backup-dir)
            require_option_value "$1" "${2:-}"
            [[ -z "$BACKUP_DIR" ]] ||
                usage_error '--backup-dir may only be provided once' 64
            BACKUP_DIR="$2"
            shift
            ;;

        --backup-dir=*)
            value="${1#--backup-dir=}"
            require_option_value '--backup-dir' "$value"
            [[ -z "$BACKUP_DIR" ]] ||
                usage_error '--backup-dir may only be provided once' 64
            BACKUP_DIR="$value"
            ;;

        --json)
            [[ "$JSON_OUTPUT" == false ]] ||
                usage_error 'self-update does not accept duplicate --json' 64
            JSON_OUTPUT=true
            ;;

        *)
            usage_error "unknown option: $1" 64
            ;;
    esac

    shift
done

if [[ -z "$MODE" ]]; then
    if [[ "$JSON_OUTPUT" == true ]]; then
        usage_error 'self-update requires --check or --apply' 64
    fi
    usage >&2
    exit 64
fi

if [[ "$MODE" == check && -n "$BACKUP_DIR" ]]; then
    usage_error '--backup-dir is only valid with --apply' 64
fi

if [[ "$MODE" == apply && -z "$EXPECTED_SHA256" ]]; then
    usage_error '--apply requires --sha256 with exactly 64 hexadecimal characters' 64
fi

if [[ -n "$EXPECTED_SHA256" &&
      ! "$EXPECTED_SHA256" =~ ^[0-9a-f]{64}$ ]]; then
    usage_error '--sha256 must contain exactly 64 hexadecimal characters' 64
fi

if [[ "$JSON_OUTPUT" != true ]]; then
    if [[ "$MODE" == check ]]; then
        tadk_heading "$(tadk_text 'self_update.preflight_heading')"
        tadk_label archive "$CHECK_ARCHIVE"
        tadk_text 'self_update.read_only'
        printf '\n\n'
    else
        tadk_heading "$(tadk_text 'self_update.apply_heading')"
        tadk_label archive "$APPLY_ARCHIVE"
        tadk_text 'self_update.transactional'
        printf '\n\n'
    fi
fi

trap tadk_self_update_handle_exit EXIT
trap 'tadk_self_update_handle_signal INT' INT
trap 'tadk_self_update_handle_signal TERM' TERM
trap 'tadk_self_update_handle_signal HUP' HUP

if [[ "$MODE" == check ]]; then
    tadk_self_update_run_check \
        "$CHECK_ARCHIVE" \
        "$EXPECTED_SHA256" \
        "$JSON_OUTPUT" \
        "$TADK_ROOT"

    if [[ "$JSON_OUTPUT" == true ]]; then
        tadk_self_update_print_json
    else
        printf '\n'
        tadk_self_update_print_summary
    fi

    if (( TADK_SELF_UPDATE_FAILED != 0 )); then
        exit 1
    fi

    exit 0
fi

apply_status=0
if tadk_self_update_apply \
    "$APPLY_ARCHIVE" \
    "$EXPECTED_SHA256" \
    "$BACKUP_DIR" \
    "$JSON_OUTPUT" \
    "$TADK_ROOT"; then
    apply_status=0
else
    apply_status=$?
fi

if [[ "$JSON_OUTPUT" == true ]]; then
    if [[ "$TADK_SELF_UPDATE_JSON_EMITTED" != true ]]; then
        tadk_self_update_print_json
    fi
elif (( apply_status == 0 )); then
    printf '\n'
    tadk_success "$(tadk_text 'self_update.committed')"
else
    printf '\n'
    tadk_error "$(tadk_text 'self_update.failed')"
fi

exit "$apply_status"
