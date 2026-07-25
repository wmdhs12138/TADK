#!/data/data/com.termux/files/usr/bin/bash

if [[ -n "${TADK_RELEASE_INIT_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_RELEASE_INIT_SH_LOADED=1

tadk_release_init_validate_environment_name() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：环境变量名称校验需要一个参数"
        return 64
    fi

    [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

tadk_release_init_read_environment() {
    if (( $# != 2 )); then
        tadk_error \
            "内部错误：环境变量读取需要名称和用途"
        return 64
    fi

    local environment_name="$1"
    local purpose="$2"

    tadk_release_init_validate_environment_name \
        "$environment_name" || {
        tadk_error \
            "无效的环境变量名称：$environment_name"
        return 64
    }

    [[ -v "$environment_name" ]] || {
        tadk_error \
            "$purpose 环境变量未设置：$environment_name"
        return 1
    }

    [[ -n "${!environment_name}" ]] || {
        tadk_error \
            "$purpose 环境变量为空：$environment_name"
        return 1
    }

    printf '%s' "${!environment_name}"
}

tadk_release_init_escape_property() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：properties 转义需要一个参数"
        return 64
    fi

    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"

    case "$value" in
        [[:space:]#!]*)
            value="\\$value"
            ;;
    esac

    value="${value//=/\\=}"
    value="${value//:/\\:}"

    printf '%s' "$value"
}

tadk_release_init_resolve_keystore() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：keystore 解析需要一个路径"
        return 64
    fi

    local requested_path="$1"
    local resolved_path=""

    resolved_path="$(
        tadk_absolute_path "$requested_path"
    )" || {
        tadk_error \
            "无法解析 keystore 路径：$requested_path"
        return 1
    }

    [[ -f "$resolved_path" ]] || {
        tadk_error "keystore 不存在：$resolved_path"
        return 1
    }

    [[ -r "$resolved_path" ]] || {
        tadk_error "keystore 不可读：$resolved_path"
        return 1
    }

    printf '%s\n' "$resolved_path"
}

tadk_release_init_validate_keystore() {
    if (( $# != 4 )); then
        tadk_error \
            "内部错误：keystore 校验需要路径、alias 和两个环境变量"
        return 64
    fi

    local keystore_path="$1"
    local alias_name="$2"
    local storepass_environment="$3"
    local keypass_environment="$4"

    local keytool_args=(
        -list
        -keystore "$keystore_path"
        -alias "$alias_name"
        -storepass:env "$storepass_environment"
    )

    if [[ -n "$keypass_environment" ]]; then
        keytool_args+=(
            -keypass:env "$keypass_environment"
        )
    fi

    tadk_require_command \
        keytool \
        "请安装完整 JDK"

    if keytool "${keytool_args[@]}" >/dev/null; then
        return 0
    fi

    local status=$?

    tadk_error \
        "keystore 或 alias 校验失败：$alias_name"

    return "$status"
}

tadk_release_init_write_properties() {
    if (( $# != 6 )); then
        tadk_error \
            "内部错误：签名配置写入参数数量错误"
        return 64
    fi

    local target_path="$1"
    local keystore_path="$2"
    local alias_name="$3"
    local store_password="$4"
    local key_password="$5"
    local force="$6"

    if [[ -e "$target_path" && "$force" != true ]]; then
        tadk_error "文件已存在，不会覆盖：$target_path"
        tadk_error \
            "确认覆盖时请使用：tadk release init --force"
        return 1
    fi

    local escaped_keystore=""
    local escaped_alias=""
    local escaped_store_password=""
    local escaped_key_password=""
    local temporary_path=""

    escaped_keystore="$(
        tadk_release_init_escape_property "$keystore_path"
    )"

    escaped_alias="$(
        tadk_release_init_escape_property "$alias_name"
    )"

    escaped_store_password="$(
        tadk_release_init_escape_property "$store_password"
    )"

    escaped_key_password="$(
        tadk_release_init_escape_property "$key_password"
    )"

    temporary_path="$target_path.tadk.$$"

    umask 077

    {
        printf 'storeFile=%s\n' "$escaped_keystore"
        printf 'storePassword=%s\n' "$escaped_store_password"
        printf 'keyAlias=%s\n' "$escaped_alias"
        printf 'keyPassword=%s\n' "$escaped_key_password"
    } > "$temporary_path"

    chmod 600 "$temporary_path"
    mv -f "$temporary_path" "$target_path"
    chmod 600 "$target_path"
}

tadk_release_init_execute() {
    if (( $# != 7 )); then
        tadk_error \
            "内部错误：release init 参数数量错误"
        return 64
    fi

    local project_root="$1"
    local requested_keystore="$2"
    local alias_name="$3"
    local storepass_environment="$4"
    local keypass_environment="$5"
    local force="$6"
    local validate_only="$7"

    local target_path="$project_root/keystore.properties"
    local keystore_path=""
    local store_password=""
    local key_password=""

    [[ -n "$requested_keystore" ]] || {
        tadk_error "init 缺少 --keystore"
        return 64
    }

    [[ -n "$alias_name" ]] || {
        tadk_error "init 缺少 --alias"
        return 64
    }

    [[ -n "$storepass_environment" ]] || {
        tadk_error "init 缺少 --storepass-env"
        return 64
    }

    case "$force" in
        true|false)
            ;;
        *)
            tadk_error "内部错误：无效的覆盖选项：$force"
            return 64
            ;;
    esac

    case "$validate_only" in
        true|false)
            ;;
        *)
            tadk_error \
                "内部错误：无效的只校验选项：$validate_only"
            return 64
            ;;
    esac

    if [[ -e "$target_path" &&
          "$force" != true &&
          "$validate_only" != true ]]; then
        tadk_error "文件已存在，不会覆盖：$target_path"
        tadk_error \
            "确认覆盖时请使用：tadk release init --force"
        return 1
    fi

    keystore_path="$(
        tadk_release_init_resolve_keystore \
            "$requested_keystore"
    )" || return $?

    store_password="$(
        tadk_release_init_read_environment \
            "$storepass_environment" \
            "keystore 密码"
    )" || return $?

    if [[ -n "$keypass_environment" ]]; then
        key_password="$(
            tadk_release_init_read_environment \
                "$keypass_environment" \
                "key 密码"
        )" || return $?
    else
        key_password="$store_password"
    fi

    tadk_release_init_validate_keystore \
        "$keystore_path" \
        "$alias_name" \
        "$storepass_environment" \
        "$keypass_environment" ||
        return $?

    tadk_heading "TADK Release Init"
    tadk_separator
    printf '项目：%s\n' "$project_root"
    printf 'keystore：%s\n' "$keystore_path"
    printf 'alias：%s\n' "$alias_name"
    printf '密码来源：环境变量\n'
    tadk_separator

    if [[ "$validate_only" == true ]]; then
        tadk_success "keystore、alias 和密码校验成功"
        return 0
    fi

    tadk_release_init_write_properties \
        "$target_path" \
        "$keystore_path" \
        "$alias_name" \
        "$store_password" \
        "$key_password" \
        "$force"

    tadk_success "已生成：$target_path"
    tadk_success "文件权限：600"
    tadk_info "下一步：tadk release build"
}
