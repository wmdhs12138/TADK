#!/usr/bin/env bash

# Read-only TADK package preflight helpers.
#
# This file is intended to be sourced by commands and tests.
# Do not enable set -e here because it would affect the caller.

if [[ -n "${TADK_SELF_UPDATE_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_SELF_UPDATE_SH_LOADED=1
readonly TADK_SELF_UPDATE_PACKAGE_CONTRACT_VERSION=1

TADK_SELF_UPDATE_JSON_OUTPUT=false
TADK_SELF_UPDATE_ARCHIVE_NAME=""
TADK_SELF_UPDATE_ARCHIVE_TYPE="unknown"
TADK_SELF_UPDATE_ARCHIVE_VERSION=""
TADK_SELF_UPDATE_ARCHIVE_SHA256=""
TADK_SELF_UPDATE_CURRENT_VERSION=""
TADK_SELF_UPDATE_STAGE=""
TADK_SELF_UPDATE_PASSED=0
TADK_SELF_UPDATE_WARNINGS=0
TADK_SELF_UPDATE_FAILED=0
declare -a TADK_SELF_UPDATE_CHECKS=()

tadk_self_update_reset() {
    TADK_SELF_UPDATE_ARCHIVE_NAME=""
    TADK_SELF_UPDATE_ARCHIVE_TYPE="unknown"
    TADK_SELF_UPDATE_ARCHIVE_VERSION=""
    TADK_SELF_UPDATE_ARCHIVE_SHA256=""
    TADK_SELF_UPDATE_CURRENT_VERSION=""
    TADK_SELF_UPDATE_STAGE=""
    TADK_SELF_UPDATE_PASSED=0
    TADK_SELF_UPDATE_WARNINGS=0
    TADK_SELF_UPDATE_FAILED=0
    TADK_SELF_UPDATE_CHECKS=()
}

tadk_self_update_json_escape() {
    if (( $# != 1 )); then
        return 64
    fi

    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"

    printf '%s' "$value"
}

tadk_self_update_record_check() {
    if (( $# != 3 )); then
        return 64
    fi

    local name="$1"
    local status="$2"
    local detail="$3"
    local escaped_name
    local escaped_status
    local escaped_detail
    local record

    case "$status" in
        pass)
            TADK_SELF_UPDATE_PASSED=$((TADK_SELF_UPDATE_PASSED + 1))
            ;;

        warn)
            TADK_SELF_UPDATE_WARNINGS=$((TADK_SELF_UPDATE_WARNINGS + 1))
            ;;

        fail)
            TADK_SELF_UPDATE_FAILED=$((TADK_SELF_UPDATE_FAILED + 1))
            ;;

        *)
            return 64
            ;;
    esac

    escaped_name="$(tadk_self_update_json_escape "$name")"
    escaped_status="$(tadk_self_update_json_escape "$status")"
    escaped_detail="$(tadk_self_update_json_escape "$detail")"

    printf -v record \
        '{"name":"%s","status":"%s","detail":"%s"}' \
        "$escaped_name" \
        "$escaped_status" \
        "$escaped_detail"

    TADK_SELF_UPDATE_CHECKS+=("$record")

    if [[ "$TADK_SELF_UPDATE_JSON_OUTPUT" != true ]]; then
        case "$status" in
            pass)
                printf 'PASS %-18s %s\n' "$name" "$detail"
                ;;

            warn)
                printf 'WARN %-18s %s\n' "$name" "$detail"
                ;;

            fail)
                printf 'FAIL %-18s %s\n' "$name" "$detail"
                ;;
        esac
    fi
}

tadk_self_update_manifest_version() {
    if (( $# != 1 )); then
        return 64
    fi

    sed -nE \
        's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
        "$1" |
        head -n 1
}

tadk_self_update_cleanup() {
    local stage="${TADK_SELF_UPDATE_STAGE:-}"

    if [[ -n "$stage" && -d "$stage" ]]; then
        rm -rf -- "$stage" || true
    fi

    TADK_SELF_UPDATE_STAGE=""
}

tadk_self_update_print_json() {
    local overall_status=pass
    local exit_code=0
    local escaped_name
    local escaped_type
    local escaped_version
    local escaped_sha256
    local escaped_current_version
    local index

    if (( TADK_SELF_UPDATE_FAILED != 0 )); then
        overall_status=fail
        exit_code=1
    elif (( TADK_SELF_UPDATE_WARNINGS != 0 )); then
        overall_status=warn
    fi

    escaped_name="$(tadk_self_update_json_escape \
        "$TADK_SELF_UPDATE_ARCHIVE_NAME")"
    escaped_type="$(tadk_self_update_json_escape \
        "$TADK_SELF_UPDATE_ARCHIVE_TYPE")"
    escaped_version="$(tadk_self_update_json_escape \
        "$TADK_SELF_UPDATE_ARCHIVE_VERSION")"
    escaped_sha256="$(tadk_self_update_json_escape \
        "$TADK_SELF_UPDATE_ARCHIVE_SHA256")"
    escaped_current_version="$(tadk_self_update_json_escape \
        "$TADK_SELF_UPDATE_CURRENT_VERSION")"

    printf \
        '{"version":1,"status":"%s","exit_code":%s,' \
        "$overall_status" \
        "$exit_code"
    printf \
        '"archive":{"name":"%s","type":"%s","version":"%s","sha256":"%s"},' \
        "$escaped_name" \
        "$escaped_type" \
        "$escaped_version" \
        "$escaped_sha256"
    printf '"current_version":"%s",' "$escaped_current_version"
    printf \
        '"summary":{"passed":%s,"warnings":%s,"failed":%s},' \
        "$TADK_SELF_UPDATE_PASSED" \
        "$TADK_SELF_UPDATE_WARNINGS" \
        "$TADK_SELF_UPDATE_FAILED"
    printf '"checks":['

    for index in "${!TADK_SELF_UPDATE_CHECKS[@]}"; do
        if (( index > 0 )); then
            printf ','
        fi

        printf '%s' "${TADK_SELF_UPDATE_CHECKS[$index]}"
    done

    printf ']}\n'
}

tadk_self_update_print_summary() {
    if (( TADK_SELF_UPDATE_FAILED != 0 )); then
        tadk_error \
            "self-update preflight failed: $TADK_SELF_UPDATE_FAILED check(s) failed"
        return 1
    fi

    if (( TADK_SELF_UPDATE_WARNINGS != 0 )); then
        tadk_warn \
            "self-update preflight passed with $TADK_SELF_UPDATE_WARNINGS warning(s)"
        return 0
    fi

    tadk_success 'self-update preflight passed'
}

tadk_self_update_run_check() {
    if (( $# != 4 )); then
        return 64
    fi

    local archive="$1"
    local expected_sha256="$2"
    local json_output="$3"
    local tadk_root="$4"
    local archive_path="$archive"
    local archive_manifest=""
    local archive_version=""
    local archive_type="unknown"
    local actual_sha256=""
    local current_version=""
    local stage=""
    local payload=""
    local payload_version=""
    local manifest_version=""
    local expected_root=""
    local unzip_status=0
    local archive_name="${archive##*/}"
    local entries=()
    local entry=""
    local entry_name=""
    local violations=()
    local directory_name=""
    local match=""
    local contract_missing=()

    tadk_self_update_reset
    TADK_SELF_UPDATE_JSON_OUTPUT="$json_output"
    TADK_SELF_UPDATE_ARCHIVE_NAME="$archive_name"

    if [[ -f "$archive" ]]; then
        archive_path="$(tadk_absolute_path "$archive" 2>/dev/null || printf '%s' "$archive")"
        tadk_self_update_record_check \
            'archive' \
            pass \
            "archive file found: $archive_path"
    else
        tadk_self_update_record_check \
            'archive' \
            fail \
            "archive file not found: $archive"
    fi

    if [[ "$archive_name" =~ ^TADK-(.+)-update\.zip$ ]]; then
        archive_type=update
        archive_version="${BASH_REMATCH[1]}"
    elif [[ "$archive_name" =~ ^TADK-(.+)\.zip$ ]]; then
        archive_type=full
        archive_version="${BASH_REMATCH[1]}"
    fi

    TADK_SELF_UPDATE_ARCHIVE_TYPE="$archive_type"
    TADK_SELF_UPDATE_ARCHIVE_VERSION="$archive_version"

    if [[ "$archive_type" == unknown ]]; then
        tadk_self_update_record_check \
            'archive_name' \
            fail \
            'archive name must be TADK-<version>.zip or TADK-<version>-update.zip'
    else
        tadk_self_update_record_check \
            'archive_name' \
            pass \
            "identified $archive_type package for version $archive_version"
    fi

    current_version="$(
        if [[ -f "$tadk_root/VERSION" ]]; then
            tr -d '\r\n' < "$tadk_root/VERSION"
        fi
    )"
    TADK_SELF_UPDATE_CURRENT_VERSION="$current_version"

    if [[ -n "$current_version" ]]; then
        tadk_self_update_record_check \
            'current_installation' \
            pass \
            "current TADK version is $current_version"
    else
        tadk_self_update_record_check \
            'current_installation' \
            fail \
            "current TADK VERSION is missing: $tadk_root/VERSION"
    fi

    if [[ ! -f "$archive" ]]; then
        tadk_self_update_record_check \
            'checksum' \
            fail \
            'cannot verify checksum because the archive is unavailable'
    elif ! tadk_command_exists sha256sum; then
        tadk_self_update_record_check \
            'checksum' \
            fail \
            'sha256sum command is required for package preflight'
    else
        actual_sha256="$(
            sha256sum "$archive" |
                awk '{print $1}'
        )"
        TADK_SELF_UPDATE_ARCHIVE_SHA256="$actual_sha256"

        if [[ -z "$expected_sha256" ]]; then
            tadk_self_update_record_check \
                'checksum' \
                warn \
                "checksum calculated but no expected SHA-256 was supplied: $actual_sha256"
        elif [[ "$actual_sha256" == "$expected_sha256" ]]; then
            tadk_self_update_record_check \
                'checksum' \
                pass \
                "SHA-256 verified: $actual_sha256"
        else
            tadk_self_update_record_check \
                'checksum' \
                fail \
                "SHA-256 mismatch: expected $expected_sha256, got $actual_sha256"
        fi
    fi

    if [[ ! -f "$archive" ]]; then
        return 0
    fi

    if ! tadk_command_exists unzip; then
        tadk_self_update_record_check \
            'archive_extract' \
            fail \
            'unzip command is required for package preflight'
        return 0
    fi

    stage="$(mktemp -d "${TMPDIR:-/tmp}/tadk-self-update.XXXXXX")" || {
        tadk_self_update_record_check \
            'archive_extract' \
            fail \
            'could not create a temporary extraction directory'
        return 0
    }
    TADK_SELF_UPDATE_STAGE="$stage"

    unzip "$archive" -d "$stage" >/dev/null 2>&1 ||
        unzip_status=$?

    if (( unzip_status > 1 )); then
        tadk_self_update_record_check \
            'archive_extract' \
            fail \
            'archive could not be extracted'
        return 0
    fi

    if (( unzip_status == 1 )); then
        tadk_self_update_record_check \
            'archive_extract' \
            warn \
            'archive extracted with a format warning'
    else
        tadk_self_update_record_check \
            'archive_extract' \
            pass \
            'archive extracted into a temporary directory'
    fi

    while IFS= read -r entry; do
        [[ -n "$entry" ]] || continue
        entries+=("$entry")
    done < <(find "$stage" -mindepth 1 -maxdepth 1 -print)

    if (( ${#entries[@]} != 1 )); then
        tadk_self_update_record_check \
            'archive_layout' \
            fail \
            "archive must contain one top-level directory, found ${#entries[@]}"
        return 0
    fi

    entry="${entries[0]}"
    entry_name="${entry##*/}"
    expected_root="TADK-$archive_version"

    if [[ ! -d "$entry" || "$entry_name" != "$expected_root" ]]; then
        tadk_self_update_record_check \
            'archive_layout' \
            fail \
            "expected top-level directory $expected_root"
        return 0
    fi

    payload="$entry"
    tadk_self_update_record_check \
        'archive_layout' \
        pass \
        "top-level directory is $entry_name"

    if [[ -f "$payload/VERSION" ]]; then
        payload_version="$(tr -d '\r\n' < "$payload/VERSION")"
        if [[ "$payload_version" == "$archive_version" ]]; then
            tadk_self_update_record_check \
                'version' \
                pass \
                "archive VERSION is $payload_version"
        else
            tadk_self_update_record_check \
                'version' \
                fail \
                "archive VERSION is $payload_version, expected $archive_version"
        fi
    else
        tadk_self_update_record_check \
            'version' \
            fail \
            'archive VERSION file is missing'
    fi

    archive_manifest="$payload/release/manifest.json"
    if [[ ! -f "$archive_manifest" ]]; then
        tadk_self_update_record_check \
            'manifest' \
            fail \
            'archive release/manifest.json is missing'
    else
        manifest_version="$(tadk_self_update_manifest_version "$archive_manifest")"
        if [[ "$manifest_version" == "$archive_version" ]]; then
            tadk_self_update_record_check \
                'manifest' \
                pass \
                "release manifest version is $manifest_version"
        else
            tadk_self_update_record_check \
                'manifest' \
                fail \
                "release manifest version is ${manifest_version:-missing}, expected $archive_version"
        fi

        for match in \
            '"version": 1' \
            '"full_archive": "TADK-{version}.zip"' \
            '"update_archive": "TADK-{version}-update.zip"' \
            '"root_directory": "TADK-{version}"' \
            '"checksum": "SHA-256"' \
            '"payload": "tracked-files"' \
            '"update_scope": "changed-tracked-files"'; do
            grep -Fq "$match" "$archive_manifest" ||
                contract_missing+=("$match")
        done

        if (( ${#contract_missing[@]} == 0 )); then
            tadk_self_update_record_check \
                'package_contract' \
                pass \
                'package contract version 1 is present'
        else
            tadk_self_update_record_check \
                'package_contract' \
                fail \
                "package contract is missing: ${contract_missing[*]}"
        fi
    fi

    for directory_name in .git .tadk build .gradle; do
        while IFS= read -r match; do
            [[ -n "$match" ]] || continue
            violations+=("${match#"$payload"/}")
        done < <(find "$payload" -type d -name "$directory_name" -print)
    done

    while IFS= read -r match; do
        [[ -n "$match" ]] || continue
        violations+=("${match#"$payload"/}")
    done < <(
        find "$payload" -type f \( \
            -name '*.jks' -o \
            -name '*.keystore' -o \
            -name 'keystore.properties' \
        \) -print
    )

    if (( ${#violations[@]} == 0 )); then
        tadk_self_update_record_check \
            'preserved_paths' \
            pass \
            'archive does not contain protected user state or build outputs'
    else
        tadk_self_update_record_check \
            'preserved_paths' \
            fail \
            "archive contains protected paths: ${violations[*]}"
    fi
}
