#!/usr/bin/env bash

# Read-only TADK package preflight helpers.
#
# This file is intended to be sourced by commands.
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
TADK_SELF_UPDATE_PAYLOAD=""
TADK_SELF_UPDATE_KEEP_STAGE=false
TADK_SELF_UPDATE_PASSED=0
TADK_SELF_UPDATE_WARNINGS=0
TADK_SELF_UPDATE_FAILED=0
TADK_SELF_UPDATE_CACHE_ROOT=""
TADK_SELF_UPDATE_LOCK_DIR=""
TADK_SELF_UPDATE_LOCK_ACQUIRED=false
TADK_SELF_UPDATE_BACKUP_DIR=""
TADK_SELF_UPDATE_BACKUP_DIR_CREATED=false
TADK_SELF_UPDATE_BACKUP_COMPLETE=false
TADK_SELF_UPDATE_TRANSACTION_ACTIVE=false
TADK_SELF_UPDATE_ROLLBACK_IN_PROGRESS=false
TADK_SELF_UPDATE_ROLLBACK_DONE=false
TADK_SELF_UPDATE_APPLY_COMPLETED=false
TADK_SELF_UPDATE_INTERRUPTED=false
TADK_SELF_UPDATE_JSON_EMITTED=false
TADK_SELF_UPDATE_EXIT_HANDLING=false
TADK_SELF_UPDATE_ORIGINAL_EXIT_CODE=0
declare -a TADK_SELF_UPDATE_CHECKS=()

tadk_self_update_reset() {
    TADK_SELF_UPDATE_ARCHIVE_NAME=""
    TADK_SELF_UPDATE_ARCHIVE_TYPE="unknown"
    TADK_SELF_UPDATE_ARCHIVE_VERSION=""
    TADK_SELF_UPDATE_ARCHIVE_SHA256=""
    TADK_SELF_UPDATE_CURRENT_VERSION=""
    TADK_SELF_UPDATE_STAGE=""
    TADK_SELF_UPDATE_PAYLOAD=""
    TADK_SELF_UPDATE_KEEP_STAGE=false
    TADK_SELF_UPDATE_PASSED=0
    TADK_SELF_UPDATE_WARNINGS=0
    TADK_SELF_UPDATE_FAILED=0
    TADK_SELF_UPDATE_JSON_EMITTED=false
    TADK_SELF_UPDATE_EXIT_HANDLING=false
    TADK_SELF_UPDATE_ORIGINAL_EXIT_CODE=0
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

tadk_self_update_resolve_path() {
    if (( $# != 1 )); then
        return 64
    fi

    local requested_path="$1"

    if tadk_command_exists realpath; then
        realpath -m -- "$requested_path"
        return $?
    fi

    if [[ -e "$requested_path" || -L "$requested_path" ]]; then
        tadk_absolute_path "$requested_path"
        return $?
    fi

    local parent_path
    parent_path="$(dirname -- "$requested_path")"
    [[ -d "$parent_path" ]] || return 1
    printf '%s/%s\n' \
        "$(cd -P -- "$parent_path" && pwd)" \
        "$(basename -- "$requested_path")"
}

tadk_self_update_acquire_lock() {
    local cache_root=""

    cache_root="$(tadk_self_update_cache_root 2>/dev/null)" || {
        tadk_self_update_record_check \
            'lock' \
            fail \
            'could not create the self-update cache directory'
        return 1
    }

    TADK_SELF_UPDATE_LOCK_DIR="$cache_root/update.lock"

    if mkdir -- "$TADK_SELF_UPDATE_LOCK_DIR" 2>/dev/null; then
        if printf '%s\n' "$$" > "$TADK_SELF_UPDATE_LOCK_DIR/pid"; then
            TADK_SELF_UPDATE_LOCK_ACQUIRED=true
            tadk_self_update_record_check \
                'lock' \
                pass \
                'exclusive self-update lock acquired'
            return 0
        fi

        rm -rf -- "$TADK_SELF_UPDATE_LOCK_DIR" || true
        TADK_SELF_UPDATE_LOCK_DIR=""
    fi

    tadk_self_update_record_check \
        'lock' \
        fail \
        'another self-update transaction is already in progress'
    return 1
}

tadk_self_update_check_apply_guards() {
    if (( $# != 2 )); then
        return 64
    fi

    local tadk_root="$1"
    local requested_backup_dir="$2"
    local resolved_root=""
    local resolved_backup=""
    local backup_parent=""
    local git_status=""

    if [[ -L "$tadk_root" ]]; then
        tadk_self_update_record_check \
            'target_root' \
            fail \
            'TADK_ROOT must not be a symbolic link'
        return 1
    fi

    if [[ ! -d "$tadk_root" ]]; then
        tadk_self_update_record_check \
            'target_root' \
            fail \
            "TADK_ROOT is not a directory: $tadk_root"
        return 1
    fi

    resolved_root="$(tadk_self_update_resolve_path "$tadk_root")" || {
        tadk_self_update_record_check \
            'target_root' \
            fail \
            'could not resolve TADK_ROOT for safety checks'
        return 1
    }

    tadk_self_update_record_check \
        'target_root' \
        pass \
        "TADK_ROOT is a real directory: $resolved_root"

    if [[ -e "$tadk_root/.git" || -L "$tadk_root/.git" ]]; then
        if ! tadk_command_exists git; then
            tadk_self_update_record_check \
                'git_worktree' \
                fail \
                'git is required to verify a Git worktree is clean'
        else
            if git_status="$(git -C "$tadk_root" status --porcelain --untracked-files=all 2>/dev/null)"; then
                if [[ -n "$git_status" ]]; then
                    tadk_self_update_record_check \
                        'git_worktree' \
                        fail \
                        'Git worktree is dirty; apply refuses to overwrite local changes'
                else
                    tadk_self_update_record_check \
                        'git_worktree' \
                        pass \
                        'Git worktree is clean'
                fi
            else
                tadk_self_update_record_check \
                    'git_worktree' \
                    fail \
                    'could not verify Git worktree status'
            fi
        fi
    else
        tadk_self_update_record_check \
            'git_worktree' \
            pass \
            'target is not a Git worktree'
    fi

    if [[ -n "$requested_backup_dir" ]]; then
        resolved_backup="$(tadk_self_update_resolve_path "$requested_backup_dir")" || {
            tadk_self_update_record_check \
                'backup_location' \
                fail \
                'could not resolve --backup-dir'
            return 1
        }
    else
        [[ -n "$TADK_SELF_UPDATE_CACHE_ROOT" ]] || {
            tadk_self_update_record_check \
                'backup_location' \
                fail \
                'self-update cache root is unavailable'
            return 1
        }
        resolved_backup="$TADK_SELF_UPDATE_CACHE_ROOT/backups/TADK-${TADK_SELF_UPDATE_ARCHIVE_VERSION}-$(date +%s)-$$-$RANDOM"
    fi

    case "$resolved_backup" in
        "$resolved_root"|"$resolved_root"/*)
            tadk_self_update_record_check \
                'backup_location' \
                fail \
                'backup directory must be outside TADK_ROOT'
            return 1
            ;;
    esac

    if [[ -L "$resolved_backup" ]]; then
        tadk_self_update_record_check \
            'backup_location' \
            fail \
            'backup directory must not be a symbolic link'
        return 1
    fi

    if [[ -e "$resolved_backup" ]]; then
        if [[ ! -d "$resolved_backup" ]]; then
            tadk_self_update_record_check \
                'backup_location' \
                fail \
                'backup path exists but is not a directory'
            return 1
        fi

        if [[ -n "$(find "$resolved_backup" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
            tadk_self_update_record_check \
                'backup_location' \
                fail \
                'backup directory must be new or empty'
            return 1
        fi
    else
        backup_parent="$(dirname -- "$resolved_backup")"
        if [[ -e "$backup_parent" && ! -d "$backup_parent" ]]; then
            tadk_self_update_record_check \
                'backup_location' \
                fail \
                'backup directory parent is not a directory'
            return 1
        fi
    fi

    TADK_SELF_UPDATE_BACKUP_DIR="$resolved_backup"
    tadk_self_update_record_check \
        'backup_location' \
        pass \
        "backup will be created outside TADK_ROOT: $resolved_backup"
}

tadk_self_update_create_backup() {
    if (( $# != 1 )); then
        return 64
    fi

    local tadk_root="$1"
    local backup_dir="$TADK_SELF_UPDATE_BACKUP_DIR"
    local backup_parent=""
    local backup_was_present=false

    [[ -n "$backup_dir" ]] || {
        tadk_self_update_record_check \
            'backup' \
            fail \
            'backup directory was not prepared'
        return 1
    }

    if [[ -e "$backup_dir" ]]; then
        backup_was_present=true
    else
        backup_parent="$(dirname -- "$backup_dir")"
        mkdir -p -- "$backup_parent" || {
            tadk_self_update_record_check \
                'backup' \
                fail \
                'could not create the backup directory parent'
            return 1
        }
        mkdir -- "$backup_dir" || {
            tadk_self_update_record_check \
                'backup' \
                fail \
                'could not create the backup directory'
            return 1
        }
        TADK_SELF_UPDATE_BACKUP_DIR_CREATED=true
    fi

    if [[ "$backup_was_present" == true &&
          -n "$(find "$backup_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        tadk_self_update_record_check \
            'backup' \
            fail \
            'backup directory became non-empty before the snapshot was created'
        return 1
    fi

    if cp -a -- "$tadk_root"/. "$backup_dir"/ 2>/dev/null; then
        TADK_SELF_UPDATE_BACKUP_COMPLETE=true
        tadk_self_update_record_check \
            'backup' \
            pass \
            "complete TADK installation backup created at $backup_dir"
        return 0
    fi

    tadk_self_update_record_check \
        'backup' \
        fail \
        'could not create a complete TADK installation backup'
    return 1
}

tadk_self_update_apply_rollback() {
    if (( $# != 1 )); then
        return 64
    fi

    local original_version="$1"
    local tadk_root="${TADK_SELF_UPDATE_APPLY_ROOT:-}"
    local backup_dir="$TADK_SELF_UPDATE_BACKUP_DIR"
    local child=""
    local restore_status=0
    local restored_version=""

    if [[ "${TADK_SELF_UPDATE_ROLLBACK_IN_PROGRESS:-false}" == true ]]; then
        return 1
    fi

    TADK_SELF_UPDATE_ROLLBACK_IN_PROGRESS=true

    if [[ -z "$tadk_root" || ! -d "$tadk_root" ||
          "$TADK_SELF_UPDATE_BACKUP_COMPLETE" != true ]]; then
        tadk_self_update_record_check \
            'rollback' \
            fail \
            'rollback could not start because the complete backup is unavailable'
        TADK_SELF_UPDATE_ROLLBACK_IN_PROGRESS=false
        TADK_SELF_UPDATE_ROLLBACK_DONE=true
        return 1
    fi

    while IFS= read -r -d '' child; do
        rm -rf -- "$child" || restore_status=1
    done < <(find "$tadk_root" -mindepth 1 -maxdepth 1 -print0)

    if (( restore_status == 0 )) &&
       ! cp -a -- "$backup_dir"/. "$tadk_root"/ 2>/dev/null; then
        restore_status=1
    fi

    if (( restore_status == 0 )); then
        restored_version="$(
            if [[ -f "$tadk_root/VERSION" ]]; then
                tr -d '\r\n' < "$tadk_root/VERSION"
            fi
        )"
        if [[ "$restored_version" != "$original_version" ]]; then
            restore_status=1
        fi
    fi

    if (( restore_status == 0 )); then
        tadk_self_update_record_check \
            'rollback' \
            pass \
            "automatic rollback restored TADK version $restored_version"
    else
        tadk_self_update_record_check \
            'rollback' \
            fail \
            'automatic rollback could not restore the complete installation'
    fi

    TADK_SELF_UPDATE_ROLLBACK_IN_PROGRESS=false
    TADK_SELF_UPDATE_ROLLBACK_DONE=true
    TADK_SELF_UPDATE_TRANSACTION_ACTIVE=false
    return "$restore_status"
}

tadk_self_update_apply_fail_and_rollback() {
    if (( $# != 4 )); then
        return 64
    fi

    local check_name="$1"
    local detail="$2"
    local original_version="$3"
    local original_status="$4"

    tadk_self_update_record_check \
        "$check_name" \
        fail \
        "$detail"

    # Rollback diagnostics are recorded by tadk_self_update_apply_rollback, but
    # never replace the failure status from the operation that triggered it.
    tadk_self_update_apply_rollback "$original_version" || true
    return "$original_status"
}

tadk_self_update_verify_installation() {
    if (( $# != 1 )); then
        return 64
    fi

    local tadk_root="$1"
    local required_file
    local command_name
    local description
    local relative_target
    local target_path

    [[ -d "$tadk_root" ]] || return 1

    for required_file in \
        VERSION \
        release/manifest.json \
        bin/tadk \
        commands/manifest
    do
        if [[ ! -f "$tadk_root/$required_file" ]]; then
            tadk_error "安装文件缺失：$required_file"
            return 1
        fi
    done

    if [[ ! -x "$tadk_root/bin/tadk" ]]; then
        tadk_error '主命令入口不可执行：bin/tadk'
        return 1
    fi

    while IFS='|' read -r command_name description relative_target; do
        [[ -n "$command_name" ]] || continue
        [[ "$command_name" == \#* ]] && continue

        if [[ -z "$description" || -z "$relative_target" ]]; then
            tadk_error "命令清单条目不完整：$command_name"
            return 1
        fi

        case "$relative_target" in
            /*|../*|*/../*|*/..)
                tadk_error "命令清单目标越界：$relative_target"
                return 1
                ;;
        esac

        target_path="$tadk_root/$relative_target"
        if [[ ! -f "$target_path" || ! -x "$target_path" ]]; then
            tadk_error "命令清单目标不可执行：$relative_target"
            return 1
        fi
    done < "$tadk_root/commands/manifest"
}

tadk_self_update_apply() {
    if (( $# != 5 )); then
        return 64
    fi

    local archive="$1"
    local expected_sha256="$2"
    local requested_backup_dir="$3"
    local json_output="$4"
    local tadk_root="$5"
    local observed_version=""
    local original_version=""
    local failure_status=0

    TADK_SELF_UPDATE_APPLY_ROOT="$tadk_root"
    TADK_SELF_UPDATE_TRANSACTION_ACTIVE=false
    TADK_SELF_UPDATE_ROLLBACK_DONE=false
    TADK_SELF_UPDATE_APPLY_COMPLETED=false
    TADK_SELF_UPDATE_BACKUP_COMPLETE=false
    TADK_SELF_UPDATE_BACKUP_DIR_CREATED=false

    tadk_self_update_run_check \
        "$archive" \
        "$expected_sha256" \
        "$json_output" \
        "$tadk_root" \
        true

    if (( TADK_SELF_UPDATE_FAILED != 0 )); then
        return 1
    fi

    original_version="$TADK_SELF_UPDATE_CURRENT_VERSION"

    if ! tadk_self_update_acquire_lock; then
        return 1
    fi

    if ! tadk_self_update_check_apply_guards \
        "$tadk_root" \
        "$requested_backup_dir"; then
        return 1
    fi

    if (( TADK_SELF_UPDATE_FAILED != 0 )); then
        return 1
    fi

    if ! tadk_self_update_create_backup "$tadk_root"; then
        return 1
    fi

    TADK_SELF_UPDATE_TRANSACTION_ACTIVE=true

    if cp -a -- "$TADK_SELF_UPDATE_PAYLOAD"/. "$tadk_root"/ 2>/dev/null; then
        tadk_self_update_record_check \
            'apply_copy' \
            pass \
            'archive payload copied with additive/overwrite semantics'
    else
        failure_status=$?
        tadk_self_update_apply_fail_and_rollback \
            'apply_copy' \
            'archive payload copy failed; automatic rollback started' \
            "$original_version" \
            "$failure_status" || true
        return "$failure_status"
    fi

    observed_version="$(
        if [[ -f "$tadk_root/VERSION" ]]; then
            tr -d '\r\n' < "$tadk_root/VERSION"
        fi
    )"
    if [[ "$observed_version" == "$TADK_SELF_UPDATE_ARCHIVE_VERSION" ]]; then
        tadk_self_update_record_check \
            'post_apply_version' \
            pass \
            "installed VERSION is $observed_version"
    else
        failure_status=1
        tadk_self_update_apply_fail_and_rollback \
            'post_apply_version' \
            "installed VERSION is ${observed_version:-missing}, expected $TADK_SELF_UPDATE_ARCHIVE_VERSION; automatic rollback started" \
            "$original_version" \
            "$failure_status" || true
        return "$failure_status"
    fi

    if tadk_self_update_verify_installation "$tadk_root"; then
        tadk_self_update_record_check \
            'post_apply_installation' \
            pass \
            'TADK installation files and command targets are ready'
    else
        failure_status=1
        tadk_self_update_apply_fail_and_rollback \
            'post_apply_installation' \
            'TADK installation is incomplete; automatic rollback started' \
            "$original_version" \
            "$failure_status" || true
        return "$failure_status"
    fi

    TADK_SELF_UPDATE_TRANSACTION_ACTIVE=false
    TADK_SELF_UPDATE_APPLY_COMPLETED=true
    tadk_self_update_record_check \
        'apply' \
        pass \
        "TADK self-update applied successfully; backup retained at $TADK_SELF_UPDATE_BACKUP_DIR"
    return 0
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

tadk_self_update_cache_root() {
    if [[ -z "${HOME:-}" ]]; then
        return 1
    fi

    local cache_root="$HOME/.cache/tadk/self-update"

    mkdir -p -- "$cache_root" || return 1
    TADK_SELF_UPDATE_CACHE_ROOT="$cache_root"
    printf '%s\n' "$cache_root"
}

tadk_self_update_cleanup() {
    local stage="${TADK_SELF_UPDATE_STAGE:-}"
    local lock_dir="${TADK_SELF_UPDATE_LOCK_DIR:-}"
    local backup_dir="${TADK_SELF_UPDATE_BACKUP_DIR:-}"

    if [[ -n "$stage" && -d "$stage" ]]; then
        rm -rf -- "$stage" || true
    fi

    if [[ "${TADK_SELF_UPDATE_BACKUP_COMPLETE:-false}" != true &&
          "${TADK_SELF_UPDATE_BACKUP_DIR_CREATED:-false}" == true &&
          -n "$backup_dir" && -d "$backup_dir" ]]; then
        rm -rf -- "$backup_dir" || true
    fi

    if [[ "${TADK_SELF_UPDATE_LOCK_ACQUIRED:-false}" == true &&
          -n "$lock_dir" && -d "$lock_dir" ]]; then
        rm -rf -- "$lock_dir" || true
    fi

    TADK_SELF_UPDATE_STAGE=""
    TADK_SELF_UPDATE_LOCK_DIR=""
    TADK_SELF_UPDATE_LOCK_ACQUIRED=false
    TADK_SELF_UPDATE_TRANSACTION_ACTIVE=false
}

tadk_self_update_handle_exit() {
    local original_status=$?

    if [[ "${TADK_SELF_UPDATE_EXIT_HANDLING:-false}" == true ]]; then
        return "$original_status"
    fi

    TADK_SELF_UPDATE_EXIT_HANDLING=true
    TADK_SELF_UPDATE_ORIGINAL_EXIT_CODE="$original_status"

    if [[ "${TADK_SELF_UPDATE_TRANSACTION_ACTIVE:-false}" == true &&
          "${TADK_SELF_UPDATE_BACKUP_COMPLETE:-false}" == true &&
          "${TADK_SELF_UPDATE_APPLY_COMPLETED:-false}" != true &&
          "${TADK_SELF_UPDATE_ROLLBACK_DONE:-false}" != true ]]; then
        # Keep the exit status that caused termination even if rollback itself
        # reports a failure.  The rollback check remains in the result output.
        tadk_self_update_apply_rollback \
            "$TADK_SELF_UPDATE_CURRENT_VERSION" || true
    fi

    if [[ "${TADK_SELF_UPDATE_JSON_OUTPUT:-false}" == true &&
          "${TADK_SELF_UPDATE_JSON_EMITTED:-false}" != true ]]; then
        tadk_self_update_print_json || true
    fi

    tadk_self_update_cleanup
    TADK_SELF_UPDATE_EXIT_HANDLING=false
    return "$original_status"
}

tadk_self_update_handle_signal() {
    if (( $# != 1 )); then
        return 64
    fi

    local signal="$1"
    local exit_code=1

    case "$signal" in
        HUP)
            exit_code=129
            ;;

        INT)
            exit_code=130
            ;;

        TERM)
            exit_code=143
            ;;

        *)
            exit_code=1
            ;;
    esac

    TADK_SELF_UPDATE_INTERRUPTED=true

    if [[ "${TADK_SELF_UPDATE_JSON_OUTPUT:-false}" == true &&
          "${TADK_SELF_UPDATE_JSON_EMITTED:-false}" != true ]]; then
        tadk_self_update_record_check \
            'signal' \
            fail \
            "self-update interrupted by $signal"
    fi

    # exit invokes the single EXIT handler, which performs rollback, emits
    # JSON once, cleans temporary state, and restores this status.
    exit "$exit_code"
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
    TADK_SELF_UPDATE_JSON_EMITTED=true
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
    if (( $# != 4 && $# != 5 )); then
        return 64
    fi

    local archive="$1"
    local expected_sha256="$2"
    local json_output="$3"
    local tadk_root="$4"
    local keep_stage="${5:-false}"
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

    case "$keep_stage" in
        true|false)
            ;;

        *)
            return 64
            ;;
    esac

    tadk_self_update_reset
    TADK_SELF_UPDATE_JSON_OUTPUT="$json_output"
    TADK_SELF_UPDATE_ARCHIVE_NAME="$archive_name"
    TADK_SELF_UPDATE_KEEP_STAGE="$keep_stage"

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

    local cache_root=""
    cache_root="$(tadk_self_update_cache_root 2>/dev/null)" || {
        tadk_self_update_record_check \
            'archive_extract' \
            fail \
            'could not create the self-update cache directory under $HOME/.cache/tadk/self-update'
        return 0
    }

    stage="$(mktemp -d "$cache_root/stage.XXXXXX")" || {
        tadk_self_update_record_check \
            'archive_extract' \
            fail \
            'could not create a temporary extraction directory under $HOME/.cache/tadk/self-update'
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
    TADK_SELF_UPDATE_PAYLOAD="$payload"
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

    while IFS= read -r match; do
        [[ -n "$match" ]] || continue
        violations+=("${match#"$payload"/} (symlink)")
    done < <(find "$payload" -type l -print)

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
