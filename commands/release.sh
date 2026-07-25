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

usage() {
    cat <<'HELP'
用法：
  tadk release doctor
  tadk release verify [APK]

操作：
  doctor              检查 Android Release 签名验证环境
  verify [APK]        验证 APK 签名、证书和文件摘要

说明：
  verify 未指定 APK 时，将在当前 Android 项目中查找最新的
  Release APK。如果存在 .tadk/project.conf，则只检查配置的 module。

  本命令不会：
    - 创建或修改 keystore
    - 读取或保存签名密码
    - 修改 Gradle signingConfig
    - 构建 APK

示例：
  tadk release doctor
  tadk release verify
  tadk release verify app/build/outputs/apk/release/app-release.apk
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

while (( $# > 0 )); do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;

        -*)
            tadk_die "未知参数：$1" 64
            ;;

        *)
            if [[ -z "$ACTION" ]]; then
                ACTION="$1"
            elif [[ "$ACTION" == "verify" &&
                    -z "$APK_ARGUMENT" ]]; then
                APK_ARGUMENT="$1"
            else
                tadk_die "多余参数：$1" 64
            fi
            ;;
    esac

    shift
done

[[ -n "$ACTION" ]] || {
    usage
    exit 64
}

case "$ACTION" in
    doctor)
        [[ -z "$APK_ARGUMENT" ]] ||
            tadk_die "doctor 不接受 APK 参数" 64

        release_doctor
        ;;

    verify)
        APK_PATH="$(
            resolve_verify_apk "$APK_ARGUMENT"
        )" || exit $?

        verify_apk_signature "$APK_PATH"
        ;;

    *)
        tadk_die "未知 release 操作：$ACTION" 64
        ;;
esac
