#!/usr/bin/env bash

if [[ -n "${TADK_RELEASE_KEYGEN_SH_LOADED:-}" ]]; then
    return 0
fi

readonly TADK_RELEASE_KEYGEN_SH_LOADED=1

tadk_release_keygen_validate_environment_name() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：环境变量名称校验需要一个参数"
        return 64
    fi

    [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

tadk_release_keygen_require_environment() {
    if (( $# != 2 )); then
        tadk_error \
            "内部错误：环境变量检查需要名称和用途"
        return 64
    fi

    local environment_name="$1"
    local purpose="$2"
    local environment_value=""

    tadk_release_keygen_validate_environment_name \
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

    environment_value="${!environment_name}"

    [[ -n "$environment_value" ]] || {
        tadk_error \
            "$purpose 环境变量为空：$environment_name"
        return 1
    }

    if (( ${#environment_value} < 6 )); then
        tadk_error \
            "$purpose 至少需要 6 个字符"
        return 1
    fi
}

tadk_release_keygen_validate_alias() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：alias 校验需要一个参数"
        return 64
    fi

    local alias_name="$1"

    [[ -n "$alias_name" ]] || {
        tadk_error "keygen 缺少 --alias"
        return 64
    }

    [[ "$alias_name" != *$'\n'* &&
       "$alias_name" != *$'\r'* ]] || {
        tadk_error "alias 不得包含换行符"
        return 64
    }
}

tadk_release_keygen_validate_dname() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：dname 校验需要一个参数"
        return 64
    fi

    local distinguished_name="$1"

    [[ -n "$distinguished_name" ]] || {
        tadk_error "keygen 缺少 --dname"
        return 64
    }

    [[ "$distinguished_name" != *$'\n'* &&
       "$distinguished_name" != *$'\r'* ]] || {
        tadk_error "dname 不得包含换行符"
        return 64
    }
}

tadk_release_keygen_resolve_target() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：keystore 目标解析需要一个路径"
        return 64
    fi

    local requested_path="$1"
    local parent_directory=""
    local file_name=""

    [[ -n "$requested_path" ]] || {
        tadk_error "keygen 缺少 --keystore"
        return 64
    }

    parent_directory="$(dirname -- "$requested_path")"
    file_name="$(basename -- "$requested_path")"

    [[ -n "$file_name" &&
       "$file_name" != "." &&
       "$file_name" != ".." &&
       "$file_name" != "/" ]] || {
        tadk_error \
            "无效的 keystore 路径：$requested_path"
        return 64
    }

    mkdir -p -- "$parent_directory"

    parent_directory="$(
        cd -- "$parent_directory"
        pwd -P
    )" || {
        tadk_error \
            "无法解析 keystore 目录：$requested_path"
        return 1
    }

    printf '%s/%s\n' "$parent_directory" "$file_name"
}

tadk_release_keygen_validate_numeric_options() {
    if (( $# != 3 )); then
        tadk_error \
            "内部错误：算法参数校验需要算法、长度和有效期"
        return 64
    fi

    local key_algorithm="$1"
    local key_size="$2"
    local validity_days="$3"

    case "$key_algorithm" in
        RSA)
            [[ "$key_size" =~ ^[0-9]+$ ]] || {
                tadk_error "无效的 RSA key size：$key_size"
                return 64
            }

            (( key_size >= 2048 )) || {
                tadk_error "RSA key size 不得小于 2048"
                return 64
            }
            ;;

        EC)
            tadk_error \
                "当前 keygen 暂不支持 EC；请使用 RSA"
            return 64
            ;;

        *)
            tadk_error \
                "不支持的密钥算法：$key_algorithm"
            return 64
            ;;
    esac

    [[ "$validity_days" =~ ^[0-9]+$ ]] || {
        tadk_error \
            "无效的有效期天数：$validity_days"
        return 64
    }

    (( validity_days > 0 )) || {
        tadk_error "有效期天数必须大于 0"
        return 64
    }
}

tadk_release_keygen_execute() {
    if (( $# != 11 )); then
        tadk_error \
            "内部错误：release keygen 参数数量错误"
        return 64
    fi

    local requested_keystore="$1"
    local alias_name="$2"
    local distinguished_name="$3"
    local storepass_environment="$4"
    local keypass_environment="$5"
    local key_algorithm="$6"
    local key_size="$7"
    local validity_days="$8"
    local store_type="$9"
    local force="${10}"
    local verbose="${11}"

    local keystore_path=""
    local temporary_path=""
    local keytool_status=0

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

    case "$store_type" in
        PKCS12|JKS)
            ;;
        *)
            tadk_error \
                "不支持的 keystore 类型：$store_type"
            return 64
            ;;
    esac

    [[ -n "$storepass_environment" ]] || {
        tadk_error "keygen 缺少 --storepass-env"
        return 64
    }

    tadk_release_keygen_validate_alias \
        "$alias_name" ||
        return $?

    tadk_release_keygen_validate_dname \
        "$distinguished_name" ||
        return $?

    tadk_release_keygen_validate_numeric_options \
        "$key_algorithm" \
        "$key_size" \
        "$validity_days" ||
        return $?

    tadk_release_keygen_require_environment \
        "$storepass_environment" \
        "keystore 密码" ||
        return $?

    if [[ -n "$keypass_environment" ]]; then
        tadk_release_keygen_require_environment \
            "$keypass_environment" \
            "key 密码" ||
            return $?
    else
        keypass_environment="$storepass_environment"
    fi

    if [[ "$store_type" == PKCS12 &&
          "${!storepass_environment}" != "${!keypass_environment}" ]]; then
        tadk_error \
            "PKCS12 不支持独立的 key 密码；两者必须相同"
        return 64
    fi

    tadk_require_command \
        keytool \
        "请安装完整 JDK"

    keystore_path="$(
        tadk_release_keygen_resolve_target \
            "$requested_keystore"
    )" || return $?

    if [[ -e "$keystore_path" ]]; then
        if [[ "$force" != true ]]; then
            tadk_error \
                "keystore 已存在，不会覆盖：$keystore_path"
            tadk_error \
                "确认替换时请使用：tadk release keygen --force"
            return 1
        fi

        [[ -f "$keystore_path" ]] || {
            tadk_error \
                "目标存在但不是普通文件：$keystore_path"
            return 1
        }
    fi

    temporary_path="$keystore_path.tadk.$$"

    [[ ! -e "$temporary_path" ]] || {
        tadk_error \
            "临时 keystore 路径已存在：$temporary_path"
        return 1
    }

    local keytool_args=(
        -genkeypair
        -keystore "$temporary_path"
        -alias "$alias_name"
        -dname "$distinguished_name"
        -keyalg "$key_algorithm"
        -keysize "$key_size"
        -validity "$validity_days"
        -storetype "$store_type"
        -storepass:env "$storepass_environment"
        -keypass:env "$keypass_environment"
    )

    if [[ "$verbose" == true ]]; then
        keytool_args+=(-v)
    fi

    tadk_heading "TADK Release Keygen"
    tadk_separator
    printf 'keystore：%s\n' "$keystore_path"
    printf 'alias：%s\n' "$alias_name"
    printf '算法：%s %s-bit\n' \
        "$key_algorithm" \
        "$key_size"
    printf '有效期：%s 天\n' "$validity_days"
    printf '类型：%s\n' "$store_type"
    printf '密码来源：环境变量\n'
    printf '覆盖已有 keystore：%s\n' "$force"
    tadk_separator

    umask 077

    if keytool "${keytool_args[@]}"; then
        keytool_status=0
    else
        keytool_status=$?
        rm -f -- "$temporary_path"
        tadk_error "keystore 生成失败"
        return "$keytool_status"
    fi

    [[ -f "$temporary_path" ]] || {
        tadk_error \
            "keytool 成功退出，但未生成 keystore"
        return 1
    }

    chmod 600 "$temporary_path"

    mv -f -- \
        "$temporary_path" \
        "$keystore_path"

    chmod 600 "$keystore_path"

    tadk_success "已生成：$keystore_path"
    tadk_success "文件权限：600"
    tadk_info \
        "请安全备份 keystore；丢失后可能无法继续发布应用更新"
}
