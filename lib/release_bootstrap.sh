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
    if (( $# != 13 )); then
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

    local resolved_keystore=""

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
        tadk_release_keygen_resolve_target \
            "$requested_keystore"
    )" || return $?

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

    tadk_release_bootstrap_run_step \
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
        "$verbose" ||
        return $?

    tadk_release_bootstrap_ignore_keystore \
        "$project_root" \
        "$resolved_keystore" ||
        return $?

    tadk_release_bootstrap_run_step \
        "生成签名配置骨架" \
        tadk_release_setup_execute \
        "$requested_module" \
        "$force" \
        "$project_root" ||
        return $?

    tadk_release_bootstrap_run_step \
        "创建本地签名配置" \
        tadk_release_init_execute \
        "$project_root" \
        "$resolved_keystore" \
        "$alias_name" \
        "$storepass_environment" \
        "$keypass_environment" \
        "$force" \
        false ||
        return $?

    tadk_release_bootstrap_run_step \
        "应用 Gradle 签名配置" \
        tadk_release_apply_execute \
        "$requested_module" \
        "$force" \
        false \
        "$project_root" ||
        return $?

    tadk_separator
    tadk_success "Release 签名初始化已完成"
    tadk_info "下一步：tadk release build"
}
