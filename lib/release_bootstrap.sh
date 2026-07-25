#!/data/data/com.termux/files/usr/bin/bash

if [[ -n "${TADK_RELEASE_BOOTSTRAP_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_RELEASE_BOOTSTRAP_SH_LOADED=1

tadk_release_bootstrap_run_step() {
    if (( $# < 2 )); then
        tadk_error \
            "内部错误：bootstrap 步骤至少需要名称和函数"
        return 64
    fi

    local step_name="$1"
    local step_function="$2"
    local step_status=0
    shift 2

    tadk_heading "Bootstrap：$step_name"

    set +e
    "$step_function" "$@"
    step_status=$?
    set -e

    if (( step_status == 0 )); then
        tadk_success "Bootstrap 步骤完成：$step_name"
        return 0
    fi

    tadk_error \
        "Bootstrap 在步骤“$step_name”停止，状态码：$step_status"

    return "$step_status"
}

tadk_release_bootstrap_resolve_target() {
    if (( $# != 1 )); then
        tadk_error \
            "internal error: bootstrap target resolution requires a path"
        return 64
    fi

    local requested_path="$1"

    [[ -n "$requested_path" ]] || {
        tadk_error "bootstrap target path must not be empty"
        return 64
    }

    case "$requested_path" in
        /*)
            printf '%s\n' "$requested_path"
            ;;

        *)
            printf '%s/%s\n' "$PWD" "$requested_path"
            ;;
    esac
}

tadk_release_bootstrap_snapshot_targets() {
    if (( $# < 2 )); then
        tadk_error \
            "internal error: bootstrap snapshot requires a directory and targets"
        return 64
    fi

    local snapshot_dir="$1"
    shift
    local manifest_path="$snapshot_dir/manifest"
    local target_path=""
    local snapshot_path=""
    local index=0
    local mode=""

    mkdir -p -- "$snapshot_dir" || return 1
    chmod 700 "$snapshot_dir" || return 1

    : > "$manifest_path" || return 1
    chmod 600 "$manifest_path" || return 1

    for target_path in "$@"; do
        [[ -n "$target_path" ]] || {
            tadk_error "internal error: bootstrap snapshot contains an empty target"
            return 64
        }

        if [[ -L "$target_path" ]]; then
            tadk_error \
                "bootstrap refuses to modify symlink target: $target_path"
            return 1
        fi

        if [[ -e "$target_path" ]]; then
            [[ -f "$target_path" ]] || {
                tadk_error \
                    "bootstrap target exists but is not a regular file: $target_path"
                return 1
            }

            snapshot_path="$snapshot_dir/file-$index"
            cp -p -- "$target_path" "$snapshot_path" || return 1
            mode="$(stat -c '%a' "$target_path")" || return 1
            printf 'present\t%s\t%s\t%s\n' \
                "$index" \
                "$mode" \
                "$target_path" \
                >> "$manifest_path" || return 1
        else
            printf 'absent\t%s\t-\t%s\n' \
                "$index" \
                "$target_path" \
                >> "$manifest_path" || return 1
        fi

        index=$((index + 1))
    done
}

tadk_release_bootstrap_restore_snapshot() {
    if (( $# != 1 )); then
        tadk_error \
            "internal error: bootstrap restore requires a snapshot directory"
        return 64
    fi

    local snapshot_dir="$1"
    local manifest_path="$snapshot_dir/manifest"
    local state=""
    local index=""
    local mode=""
    local target_path=""
    local snapshot_path=""
    local restore_status=0

    [[ -f "$manifest_path" ]] || {
        tadk_error "bootstrap snapshot manifest is missing: $manifest_path"
        return 1
    }

    while IFS=$'\t' read -r state index mode target_path; do
        [[ -n "$target_path" ]] || continue

        case "$state" in
            present)
                snapshot_path="$snapshot_dir/file-$index"
                if [[ ! -f "$snapshot_path" ]]; then
                    tadk_error \
                        "bootstrap snapshot file is missing: $snapshot_path"
                    restore_status=1
                    continue
                fi

                if [[ -e "$target_path" || -L "$target_path" ]]; then
                    if [[ ! -f "$target_path" || -L "$target_path" ]]; then
                        tadk_error \
                            "cannot restore over non-file target: $target_path"
                        restore_status=1
                        continue
                    fi
                    rm -f -- "$target_path" || {
                        restore_status=1
                        continue
                    }
                fi

                cp -p -- "$snapshot_path" "$target_path" || {
                    restore_status=1
                    continue
                }
                chmod "$mode" "$target_path" || restore_status=1
                ;;

            absent)
                if [[ -L "$target_path" || -f "$target_path" ]]; then
                    rm -f -- "$target_path" || restore_status=1
                elif [[ -e "$target_path" ]]; then
                    tadk_error \
                        "cannot remove non-file target created during rollback: $target_path"
                    restore_status=1
                fi
                ;;

            *)
                tadk_error \
                    "bootstrap snapshot contains an invalid state: $state"
                restore_status=1
                ;;
        esac
    done < "$manifest_path"

    return "$restore_status"
}

tadk_release_bootstrap_rollback() {
    if (( $# != 2 && $# != 4 )); then
        tadk_error \
            "internal error: bootstrap rollback requires snapshot and status"
        return 64
    fi

    local snapshot_dir="$1"
    local original_status="$2"
    local project_root="${3:-}"
    local tadk_directory_existed="${4:-true}"
    local restore_status=0

    case "$tadk_directory_existed" in
        true|false)
            ;;
        *)
            tadk_error "internal error: invalid .tadk directory state"
            return 64
            ;;
    esac

    tadk_warn "bootstrap failed; restoring the original Release files"
    if tadk_release_bootstrap_restore_snapshot "$snapshot_dir"; then
        tadk_warn "bootstrap rollback completed"
    else
        restore_status=$?
        tadk_error \
            "bootstrap rollback was incomplete; snapshot retained at $snapshot_dir"
    fi

    if (( restore_status == 0 )); then
        if [[ -n "$project_root" &&
              "$tadk_directory_existed" == false &&
              -d "$project_root/.tadk" &&
              ! -L "$project_root/.tadk" ]]; then
            rmdir -- "$project_root/.tadk" 2>/dev/null || true
        fi

        rm -rf -- "$snapshot_dir" || {
            tadk_warn "bootstrap snapshot cleanup failed: $snapshot_dir"
        }
        return "$original_status"
    fi

    return 1
}

tadk_release_bootstrap_ignore_keystore() {
    if (( $# != 2 )); then
        tadk_error \
            "内部错误：keystore 忽略规则需要项目和 keystore 路径"
        return 64
    fi

    local project_root="$1"
    local keystore_path="$2"
    local gitignore_path="$project_root/.gitignore"
    local relative_path=""

    case "$keystore_path" in
        "$project_root"/*)
            relative_path="${keystore_path#"$project_root"/}"
            ;;
        *)
            return 0
            ;;
    esac

    [[ -n "$relative_path" ]] || {
        tadk_error \
            "内部错误：无法生成 keystore 的项目相对路径"
        return 64
    }

    touch "$gitignore_path"

    if grep -Fqx \
        "/$relative_path" \
        "$gitignore_path"; then
        return 0
    fi

    if [[ -s "$gitignore_path" ]]; then
        printf '\n' >> "$gitignore_path"
    fi

    printf '%s\n' \
        "# TADK generated Release keystore" \
        "/$relative_path" \
        >> "$gitignore_path"

    tadk_info \
        "已加入 .gitignore：/$relative_path"
}

tadk_release_bootstrap_execute() {
    if (( $# != 13 && $# != 14 )); then
        tadk_error \
            "内部错误：release bootstrap 参数数量错误"
        return 64
    fi

    local requested_keystore="$1"
    local alias_name="$2"
    local distinguished_name="$3"
    local storepass_environment="$4"
    local keypass_environment="$5"
    local requested_module="$6"
    local key_algorithm="$7"
    local key_size="$8"
    local validity_days="$9"
    local store_type="${10}"
    local force="${11}"
    local verbose="${12}"
    local project_root="${13}"
    local dry_run="${14:-false}"

    local resolved_keystore=""
    local module=""
    local dsl=""
    local build_file=""
    local example_path="$project_root/keystore.properties.example"
    local snippet_path=""
    local properties_path="$project_root/keystore.properties"
    local gitignore_path="$project_root/.gitignore"
    local snapshot_dir=""
    local step_status=0
    local rollback_status=0
    local tadk_directory_existed=false
    local -a snapshot_targets=()

    case "$force" in
        true|false)
            ;;
        *)
            tadk_error \
                "内部错误：无效的覆盖选项：$force"
            return 64
            ;;
    esac

    case "$verbose" in
        true|false)
            ;;
        *)
            tadk_error \
                "内部错误：无效的详细输出选项：$verbose"
            return 64
            ;;
    esac

    case "$dry_run" in
        true|false)
            ;;
        *)
            tadk_error "invalid dry-run option: $dry_run"
            return 64
            ;;
    esac

    [[ -n "$requested_keystore" ]] || {
        tadk_error "bootstrap 缺少 --keystore"
        return 64
    }

    [[ -n "$alias_name" ]] || {
        tadk_error "bootstrap 缺少 --alias"
        return 64
    }

    [[ -n "$distinguished_name" ]] || {
        tadk_error "bootstrap 缺少 --dname"
        return 64
    }

    [[ -n "$storepass_environment" ]] || {
        tadk_error "bootstrap 缺少 --storepass-env"
        return 64
    }

    resolved_keystore="$(
        tadk_release_bootstrap_resolve_target \
            "$requested_keystore"
    )" || return $?

    module="$(
        tadk_release_setup_resolve_module \
            "$project_root" \
            "$requested_module"
    )" || return $?

    dsl="$(
        tadk_release_setup_detect_dsl \
            "$project_root" \
            "$module"
    )" || return $?

    build_file="$(
        tadk_release_apply_resolve_build_file \
            "$project_root" \
            "$module" \
            "$dsl"
    )" || return $?

    [[ -f "$build_file" && ! -L "$build_file" ]] || {
        tadk_error \
            "Gradle build file is missing or is a symlink: $build_file"
        return 1
    }

    case "$dsl" in
        kotlin)
            snippet_path="$project_root/.tadk/release-signing-snippet.gradle.kts"
            ;;

        groovy)
            snippet_path="$project_root/.tadk/release-signing-snippet.gradle"
            ;;

        *)
            tadk_error "internal error: unknown Gradle DSL: $dsl"
            return 64
            ;;
    esac

    local marker_state=""
    if [[ "$dry_run" == true ]]; then
        if [[ -e "$resolved_keystore" && "$force" != true ]]; then
            tadk_error \
                "keystore already exists; use --force to replace it: $resolved_keystore"
            return 1
        fi

        if [[ -e "$properties_path" && "$force" != true ]]; then
            tadk_error \
                "file already exists; use --force to replace it: $properties_path"
            return 1
        fi

        tadk_release_setup_preflight_targets \
            "$force" \
            "$example_path" \
            "$snippet_path" || return $?

        marker_state="$(
            tadk_release_apply_check_markers "$build_file"
        )" || return $?

        if [[ "$force" != true && "$marker_state" == absent ]] &&
           tadk_release_apply_has_existing_signing_config "$build_file"; then
            tadk_error \
                "existing signingConfig detected; bootstrap refuses automatic modification"
            return 1
        fi
    fi

    tadk_heading "TADK Release Bootstrap"
    tadk_separator
    printf '项目：%s\n' "$project_root"
    printf '模块：%s\n' "${requested_module:-自动检测}"
    printf 'keystore：%s\n' "$resolved_keystore"
    printf 'alias：%s\n' "$alias_name"
    printf '类型：%s\n' "$store_type"
    printf '算法：%s %s-bit\n' \
        "$key_algorithm" \
        "$key_size"
    printf '有效期：%s 天\n' "$validity_days"
    printf '覆盖已有文件：%s\n' "$force"
    tadk_separator

    if [[ "$dry_run" == true ]]; then
        tadk_info "dry-run: no files will be created or modified"
        printf '  keygen: %s\n' "$resolved_keystore"
        printf '  setup: %s\n' "$example_path"
        printf '  setup: %s\n' "$snippet_path"
        printf '  init: %s\n' "$properties_path"
        printf '  apply: %s\n' "$build_file"
        printf '  gitignore: %s\n' "$gitignore_path"
        tadk_success "Release bootstrap dry-run preflight passed"
        return 0
    fi

    snapshot_dir="$(mktemp -d "${TMPDIR:-/tmp}/tadk-release-bootstrap.XXXXXX")" || {
        tadk_error "unable to create bootstrap transaction snapshot"
        return 1
    }

    snapshot_targets=(
        "$resolved_keystore"
        "$example_path"
        "$snippet_path"
        "$properties_path"
        "$gitignore_path"
        "$build_file"
    )

    if [[ -e "$project_root/.tadk" ]]; then
        [[ -d "$project_root/.tadk" && ! -L "$project_root/.tadk" ]] || {
            tadk_error \
                "bootstrap requires .tadk to be a normal directory: $project_root/.tadk"
            rm -rf -- "$snapshot_dir"
            return 1
        }
        tadk_directory_existed=true
    fi

    if tadk_release_bootstrap_snapshot_targets \
        "$snapshot_dir" \
        "${snapshot_targets[@]}"; then
        :
    else
        step_status=$?
        rm -rf -- "$snapshot_dir"
        return "$step_status"
    fi

    tadk_info "bootstrap transaction snapshot created"

    if tadk_release_bootstrap_run_step \
        "生成 keystore" \
        tadk_release_keygen_execute \
        "$resolved_keystore" \
        "$alias_name" \
        "$distinguished_name" \
        "$storepass_environment" \
        "$keypass_environment" \
        "$key_algorithm" \
        "$key_size" \
        "$validity_days" \
        "$store_type" \
        "$force" \
        "$verbose"; then
        :
    else
        step_status=$?
        if tadk_release_bootstrap_rollback \
            "$snapshot_dir" \
            "$step_status" \
            "$project_root" \
            "$tadk_directory_existed"; then
            rollback_status=0
        else
            rollback_status=$?
        fi
        return "$rollback_status"
    fi

    if tadk_release_bootstrap_ignore_keystore \
        "$project_root" \
        "$resolved_keystore"; then
        :
    else
        step_status=$?
        if tadk_release_bootstrap_rollback \
            "$snapshot_dir" \
            "$step_status" \
            "$project_root" \
            "$tadk_directory_existed"; then
            rollback_status=0
        else
            rollback_status=$?
        fi
        return "$rollback_status"
    fi

    if tadk_release_bootstrap_run_step \
        "生成签名配置骨架" \
        tadk_release_setup_execute \
        "$requested_module" \
        "$force" \
        "$project_root"; then
        :
    else
        step_status=$?
        if tadk_release_bootstrap_rollback \
            "$snapshot_dir" \
            "$step_status" \
            "$project_root" \
            "$tadk_directory_existed"; then
            rollback_status=0
        else
            rollback_status=$?
        fi
        return "$rollback_status"
    fi

    if tadk_release_bootstrap_run_step \
        "创建本地签名配置" \
        tadk_release_init_execute \
        "$project_root" \
        "$resolved_keystore" \
        "$alias_name" \
        "$storepass_environment" \
        "$keypass_environment" \
        "$force" \
        false; then
        :
    else
        step_status=$?
        if tadk_release_bootstrap_rollback \
            "$snapshot_dir" \
            "$step_status" \
            "$project_root" \
            "$tadk_directory_existed"; then
            rollback_status=0
        else
            rollback_status=$?
        fi
        return "$rollback_status"
    fi

    if tadk_release_bootstrap_run_step \
        "应用 Gradle 签名配置" \
        tadk_release_apply_execute \
        "$requested_module" \
        "$force" \
        false \
        "$project_root"; then
        :
    else
        step_status=$?
        if tadk_release_bootstrap_rollback \
            "$snapshot_dir" \
            "$step_status" \
            "$project_root" \
            "$tadk_directory_existed"; then
            rollback_status=0
        else
            rollback_status=$?
        fi
        return "$rollback_status"
    fi

    rm -rf -- "$snapshot_dir" ||
        tadk_warn "bootstrap transaction snapshot cleanup failed: $snapshot_dir"

    tadk_separator
    tadk_success "Release 签名初始化已完成"
    tadk_info "下一步：tadk release build"
}
