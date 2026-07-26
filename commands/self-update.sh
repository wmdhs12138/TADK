#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/self_update.sh"

usage() {
    cat <<'HELP'
Usage: tadk self-update --check ARCHIVE [options]

Read-only validation for a TADK full or update archive. The command never
copies, deletes, or overwrites files in the current TADK installation.

Options:
  --check ARCHIVE       Archive to validate
  --sha256 HASH         Expected SHA-256 checksum
  --json                Print one machine-readable JSON result
  -h, --help            Show this help

Examples:
  tadk self-update --check TADK-0.3.0-alpha.19-update.zip \
    --sha256 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
  tadk self-update --check TADK-0.3.0-alpha.19.zip --json
HELP
}

CHECK_ARCHIVE=""
EXPECTED_SHA256=""
JSON_OUTPUT=false

require_option_value() {
    local option="$1"
    local value="${2:-}"

    [[ -n "$value" ]] ||
        tadk_die "$option requires a value" 64
}

while (( $# > 0 )); do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;

        --check)
            require_option_value "$1" "${2:-}"
            [[ -z "$CHECK_ARCHIVE" ]] ||
                tadk_die "--check may only be provided once" 64
            CHECK_ARCHIVE="$2"
            shift
            ;;

        --check=*)
            value="${1#--check=}"
            require_option_value '--check' "$value"
            [[ -z "$CHECK_ARCHIVE" ]] ||
                tadk_die "--check may only be provided once" 64
            CHECK_ARCHIVE="$value"
            ;;

        --sha256)
            require_option_value "$1" "${2:-}"
            [[ -z "$EXPECTED_SHA256" ]] ||
                tadk_die "--sha256 may only be provided once" 64
            EXPECTED_SHA256="${2,,}"
            shift
            ;;

        --sha256=*)
            value="${1#--sha256=}"
            require_option_value '--sha256' "$value"
            [[ -z "$EXPECTED_SHA256" ]] ||
                tadk_die "--sha256 may only be provided once" 64
            EXPECTED_SHA256="${value,,}"
            ;;

        --json)
            [[ "$JSON_OUTPUT" == false ]] ||
                tadk_die 'self-update does not accept duplicate --json' 64
            JSON_OUTPUT=true
            ;;

        *)
            tadk_die "unknown option: $1" 64
            ;;
    esac

    shift
done

[[ -n "$CHECK_ARCHIVE" ]] || {
    usage >&2
    exit 64
}

if [[ -n "$EXPECTED_SHA256" &&
      ! "$EXPECTED_SHA256" =~ ^[0-9a-f]{64}$ ]]; then
    tadk_die '--sha256 must contain exactly 64 hexadecimal characters' 64
fi

if [[ "$JSON_OUTPUT" != true ]]; then
    tadk_heading 'TADK Self-update Preflight'
    printf 'Archive: %s\n' "$CHECK_ARCHIVE"
    printf 'Mode: read-only\n\n'
fi

trap tadk_self_update_cleanup EXIT

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
