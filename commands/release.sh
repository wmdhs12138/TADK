#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"
source "$TADK_ROOT/lib/config.sh"
source "$TADK_ROOT/lib/apk.sh"

ACTION=""
APK_ARGUMENT=""
RELEASE_BUILD_ARGS=()
KEYSTORE_ARGUMENT=""
KEYSTORE_ALIAS=""
KEYSTORE_PASSWORD_ENV=""

usage() {
    cat <<'HELP'
用法：
  tadk release doctor
  tadk release verify [APK]
  tadk release build [构建选项]
  tadk release keystore KEYSTORE [选项]

操作：
  doctor              检查 Android Release 签名验证环境
  verify [APK]        验证 APK 签名、证书和文件摘要
  build               构建 Release APK 并验证签名
  keystore            检查 keystore 内容和签名证书

构建选项：
  --clean             构建前执行 Gradle clean
  --no-cache          禁用 Gradle 构建缓存
  --rerun             强制重新执行 Gradle 任务
  --                  将后续参数直接传递给 Gradle

keystore 选项：
  --alias ALIAS       只检查指定的 keystore 条目
  --storepass-env VAR 从环境变量 VAR 读取 keystore 密码

说明：
  verify 未指定 APK 时，将在当前 Android 项目中查找最新的
  Release APK。如果存在 .tadk/project.conf，则只检查配置的 module。

  build 始终构建 Release APK，并复用 tadk build 的项目配置、
  模块解析和 Gradle 参数处理。构建成功后自动执行签名验证。

  本命令不会：
    - 创建或修改 keystore
    - 读取或保存签名密码
    - 修改 Gradle signingConfig

示例：
  tadk release doctor
  tadk release verify
  tadk release verify app/build/outputs/apk/release/app-release.apk
  tadk release build
  tadk release build --clean
  tadk release build -- --stacktrace
  tadk release keystore release.jks
  tadk release keystore release.jks --alias production
  TADK_STOREPASS=secret tadk release keystore release.jks \
    --storepass-env TADK_STOREPASS
HELP
}

print_check() {
    if (( $# != 3 )); then
        tadk_error \
            "内部错误：print_check 需要 STATUS、NAME 和 DETAIL"
        return 64
    fi

    local status="$1"
    local name="$2"
    local detail="$3"

    case "$status" in
        pass)
            tadk_success "$name：$detail"
            ;;

        warn)
            tadk_warn "$name：$detail"
            ;;

        fail)
            tadk_error "$name：$detail"
            ;;

        *)
            tadk_error \
                "内部错误：未知检查状态 $status"
            return 64
            ;;
    esac
}

command_path() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：command_path 需要命令名称"
        return 64
    fi

    command -v "$1" 2>/dev/null
}

release_doctor() {
    local failure_count=0
    local resolved_path=""

    tadk_heading "TADK Release Doctor"
    tadk_separator

    if tadk_command_exists keytool; then
        resolved_path="$(command_path keytool)"
        print_check \
            pass \
            "keytool" \
            "$resolved_path"
    else
        print_check \
            fail \
            "keytool" \
            "未找到；请安装完整 JDK"
        failure_count=$((failure_count + 1))
    fi

    if tadk_command_exists apksigner; then
        resolved_path="$(command_path apksigner)"
        print_check \
            pass \
            "apksigner" \
            "$resolved_path"
    else
        print_check \
            fail \
            "apksigner" \
            "未找到；请安装 Android Build Tools"
        failure_count=$((failure_count + 1))
    fi

    if tadk_command_exists sha256sum; then
        resolved_path="$(command_path sha256sum)"
        print_check \
            pass \
            "sha256sum" \
            "$resolved_path"
    else
        print_check \
            fail \
            "sha256sum" \
            "未找到；请安装 coreutils"
        failure_count=$((failure_count + 1))
    fi

    tadk_separator

    if (( failure_count > 0 )); then
        tadk_error \
            "Release 验证环境存在 $failure_count 个问题"
        return 1
    fi

    tadk_success "Release 签名验证环境可用"
}

resolve_verify_apk() {
    local requested_path="${1:-}"
    local project_root=""
    local project_module=""
    local config_status=0
    local resolved_path=""

    if [[ -n "$requested_path" ]]; then
        resolved_path="$(
            tadk_absolute_path "$requested_path"
        )" || {
            tadk_error \
                "无法解析 APK 路径：$requested_path"
            return 1
        }

        [[ -f "$resolved_path" ]] || {
            tadk_error "APK 不存在：$resolved_path"
            return 1
        }

        case "$resolved_path" in
            *.apk)
                printf '%s\n' "$resolved_path"
                return 0
                ;;

            *)
                tadk_error "目标文件不是 APK：$resolved_path"
                return 1
                ;;
        esac
    fi

    project_root="$(tadk_require_project_root)"

    if tadk_config_load "$project_root"; then
        project_module="$TADK_CONFIG_MODULE"

        [[ -d "$project_root/$project_module" ]] || {
            tadk_error \
                "配置的模块目录不存在：$project_root/$project_module"
            return 1
        }

        resolved_path="$(
            tadk_apk_resolve_module \
                "$project_root" \
                "$project_module" \
                release
        )" || {
            tadk_error \
                "未在配置模块 $project_module 中找到 Release APK，请先执行：tadk build --release"
            return 1
        }
    else
        config_status=$?

        if (( config_status != 1 )); then
            tadk_error \
                "无法加载项目配置，状态码：$config_status"
            return "$config_status"
        fi

        resolved_path="$(
            tadk_apk_resolve \
                "$project_root" \
                release
        )" || {
            tadk_error \
                "未找到 Release APK，请先执行：tadk build --release"
            return 1
        }
    fi

    printf '%s\n' "$resolved_path"
}

validate_environment_name() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：validate_environment_name 需要变量名"
        return 64
    fi

    case "$1" in
        [A-Za-z_][A-Za-z0-9_]*)
            return 0
            ;;

        *)
            return 1
            ;;
    esac
}

resolve_keystore_path() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：resolve_keystore_path 需要路径"
        return 64
    fi

    local requested_path="$1"
    local resolved_path=""

    resolved_path="$(
        tadk_absolute_path "$requested_path"
    )" || {
        tadk_error "无法解析 keystore 路径：$requested_path"
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

inspect_keystore() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：inspect_keystore 需要 keystore 路径"
        return 64
    fi

    local keystore_path="$1"
    local keytool_args=(
        -list
        -v
        -keystore "$keystore_path"
    )
    local keytool_status=0
    local keystore_size=""
    local keystore_sha256=""

    tadk_require_command \
        keytool \
        "请安装完整 JDK"

    tadk_require_command \
        sha256sum \
        "请执行：pkg install coreutils"

    if [[ -n "$KEYSTORE_ALIAS" ]]; then
        keytool_args+=(
            -alias "$KEYSTORE_ALIAS"
        )
    fi

    if [[ -n "$KEYSTORE_PASSWORD_ENV" ]]; then
        validate_environment_name "$KEYSTORE_PASSWORD_ENV" || {
            tadk_error \
                "无效的环境变量名称：$KEYSTORE_PASSWORD_ENV"
            return 64
        }

        [[ -v "$KEYSTORE_PASSWORD_ENV" ]] || {
            tadk_error \
                "环境变量未设置：$KEYSTORE_PASSWORD_ENV"
            return 1
        }

        [[ -n "${!KEYSTORE_PASSWORD_ENV}" ]] || {
            tadk_error \
                "环境变量为空：$KEYSTORE_PASSWORD_ENV"
            return 1
        }

        keytool_args+=(
            -storepass:env "$KEYSTORE_PASSWORD_ENV"
        )
    fi

    tadk_heading "TADK Release Keystore"
    tadk_separator
    printf 'keystore：%s\n' "$keystore_path"

    if [[ -n "$KEYSTORE_ALIAS" ]]; then
        printf 'alias：%s\n' "$KEYSTORE_ALIAS"
    else
        printf 'alias：全部条目\n'
    fi

    if [[ -n "$KEYSTORE_PASSWORD_ENV" ]]; then
        printf '密码来源：环境变量 %s\n' \
            "$KEYSTORE_PASSWORD_ENV"
    else
        printf '密码来源：未提供，keytool 可能请求交互输入\n'
    fi

    keystore_size="$(tadk_apk_size "$keystore_path" || true)"
    printf '大小：%s\n' "${keystore_size:-未知}"
    tadk_separator

    if keytool "${keytool_args[@]}"; then
        keytool_status=0
    else
        keytool_status=$?
        tadk_error "keystore 检查失败"
        return "$keytool_status"
    fi

    keystore_sha256="$(
        sha256sum "$keystore_path" |
            awk '{print $1}'
    )"

    tadk_separator
    printf 'SHA-256：%s\n' "$keystore_sha256"
    tadk_success "keystore 可访问，证书信息读取成功"
}

release_build() {
    local build_status=0
    local apk_path=""

    tadk_heading "TADK Release Build"
    tadk_separator
    printf '流程：构建 Release APK 后验证签名\n'

    if (( ${#RELEASE_BUILD_ARGS[@]} > 0 )); then
        printf '构建参数：'
        printf '%q ' "${RELEASE_BUILD_ARGS[@]}"
        printf '\n'
    fi

    tadk_separator
    printf '\n'

    if "$TADK_ROOT/bin/tadk"         build         --release         "${RELEASE_BUILD_ARGS[@]}"; then
        build_status=0
    else
        build_status=$?
        tadk_error "Release 构建失败"
        return "$build_status"
    fi

    apk_path="$(
        resolve_verify_apk
    )" || return $?

    printf '\n'
    tadk_info "开始验证构建产物签名"

    verify_apk_signature "$apk_path"
}

verify_apk_signature() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：verify_apk_signature 需要 APK 路径"
        return 64
    fi

    local apk_path="$1"
    local verify_output=""
    local verify_status=0
    local sha256=""
    local apk_size=""

    tadk_require_command \
        apksigner \
        "请安装 Android Build Tools"

    tadk_require_command \
        sha256sum \
        "请执行：pkg install coreutils"

    tadk_heading "TADK Release Verify"
    tadk_separator
    printf 'APK：%s\n' "$apk_path"

    apk_size="$(tadk_apk_size "$apk_path" || true)"
    printf '大小：%s\n' "${apk_size:-未知}"
    tadk_separator

    set +e
    verify_output="$(
        apksigner verify \
            --verbose \
            --print-certs \
            "$apk_path" \
            2>&1
    )"
    verify_status=$?
    set -e

    printf '%s\n' "$verify_output"

    tadk_separator

    if (( verify_status != 0 )); then
        tadk_error "APK 签名验证失败"
        return "$verify_status"
    fi

    sha256="$(
        sha256sum "$apk_path" |
            awk '{print $1}'
    )"

    printf 'SHA-256：%s\n' "$sha256"
    tadk_success "APK 签名有效"
}

if (( $# == 0 )); then
    usage
    exit 64
fi

case "$1" in
    -h|--help)
        usage
        exit 0
        ;;

    -*)
        tadk_die "未知参数：$1" 64
        ;;

    *)
        ACTION="$1"
        shift
        ;;
esac

case "$ACTION" in
    doctor)
        (( $# == 0 )) ||
            tadk_die "doctor 不接受其他参数" 64

        release_doctor
        ;;

    verify)
        while (( $# > 0 )); do
            case "$1" in
                -h|--help)
                    usage
                    exit 0
                    ;;

                -*)
                    tadk_die "verify 不支持参数：$1" 64
                    ;;

                *)
                    [[ -z "$APK_ARGUMENT" ]] ||
                        tadk_die "verify 只接受一个 APK 路径" 64

                    APK_ARGUMENT="$1"
                    ;;
            esac

            shift
        done

        APK_PATH="$(
            resolve_verify_apk "$APK_ARGUMENT"
        )" || exit $?

        verify_apk_signature "$APK_PATH"
        ;;

    keystore)
        while (( $# > 0 )); do
            case "$1" in
                --alias)
                    shift

                    (( $# > 0 )) ||
                        tadk_die "--alias 缺少参数" 64

                    [[ -z "$KEYSTORE_ALIAS" ]] ||
                        tadk_die "--alias 不能重复指定" 64

                    KEYSTORE_ALIAS="$1"
                    ;;

                --alias=*)
                    [[ -z "$KEYSTORE_ALIAS" ]] ||
                        tadk_die "--alias 不能重复指定" 64

                    KEYSTORE_ALIAS="${1#--alias=}"

                    [[ -n "$KEYSTORE_ALIAS" ]] ||
                        tadk_die "--alias 缺少参数" 64
                    ;;

                --storepass-env)
                    shift

                    (( $# > 0 )) ||
                        tadk_die "--storepass-env 缺少参数" 64

                    [[ -z "$KEYSTORE_PASSWORD_ENV" ]] ||
                        tadk_die \
                            "--storepass-env 不能重复指定" 64

                    KEYSTORE_PASSWORD_ENV="$1"
                    ;;

                --storepass-env=*)
                    [[ -z "$KEYSTORE_PASSWORD_ENV" ]] ||
                        tadk_die \
                            "--storepass-env 不能重复指定" 64

                    KEYSTORE_PASSWORD_ENV="${1#--storepass-env=}"

                    [[ -n "$KEYSTORE_PASSWORD_ENV" ]] ||
                        tadk_die \
                            "--storepass-env 缺少参数" 64
                    ;;

                -h|--help)
                    usage
                    exit 0
                    ;;

                -*)
                    tadk_die \
                        "keystore 不支持参数：$1" 64
                    ;;

                *)
                    [[ -z "$KEYSTORE_ARGUMENT" ]] ||
                        tadk_die \
                            "keystore 只接受一个文件路径" 64

                    KEYSTORE_ARGUMENT="$1"
                    ;;
            esac

            shift
        done

        [[ -n "$KEYSTORE_ARGUMENT" ]] ||
            tadk_die "keystore 缺少文件路径" 64

        KEYSTORE_PATH="$(
            resolve_keystore_path "$KEYSTORE_ARGUMENT"
        )" || exit $?

        inspect_keystore "$KEYSTORE_PATH"
        ;;

    build)
        while (( $# > 0 )); do
            case "$1" in
                --clean|--no-cache|--rerun)
                    RELEASE_BUILD_ARGS+=("$1")
                    ;;

                --)
                    RELEASE_BUILD_ARGS+=(--)
                    shift

                    while (( $# > 0 )); do
                        RELEASE_BUILD_ARGS+=("$1")
                        shift
                    done

                    break
                    ;;

                -h|--help)
                    usage
                    exit 0
                    ;;

                *)
                    tadk_die "build 不支持参数：$1" 64
                    ;;
            esac

            shift
        done

        release_build
        ;;

    *)
        tadk_die "未知 release 操作：$ACTION" 64
        ;;
esac
