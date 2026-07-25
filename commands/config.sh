#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"
source "$TADK_ROOT/lib/config.sh"

ACTION=""
PROJECT_PATH=""

usage() {
    cat <<'HELP'
用法：
  tadk config show [PROJECT_ROOT]
  tadk config validate [PROJECT_ROOT]
  tadk config [选项]

说明：
  查看或验证当前 Android 项目的 TADK 配置。

  未提供 PROJECT_ROOT 时，从当前目录向上查找项目根目录。

子命令：
  show                显示项目配置
  validate            验证项目配置

选项：
  -h, --help          显示帮助

参数：
  PROJECT_ROOT        Android 项目根目录或项目内的任意目录

配置文件：
  .tadk/project.conf

示例：
  tadk config show
  tadk config validate
  tadk config show ~/projects/MyApp
  tadk config validate ~/projects/MyApp/app/src/main
HELP
}

resolve_project_root() {
    if [[ -n "$PROJECT_PATH" ]]; then
        if [[ ! -d "$PROJECT_PATH" ]]; then
            tadk_error "项目目录不存在：$PROJECT_PATH"
            return 1
        fi

        tadk_find_project_root "$PROJECT_PATH" || {
            tadk_error \
                "指定目录不在有效的 Gradle Android 项目中：$PROJECT_PATH"
            return 1
        }

        return 0
    fi

    tadk_find_project_root "$PWD" || {
        tadk_error "当前目录不在有效的 Gradle Android 项目中"
        return 1
    }
}

load_project_config() {
    if (( $# != 1 )); then
        tadk_error \
            '内部错误：load_project_config 需要 PROJECT_ROOT'
        return 64
    fi

    local project_root="$1"
    local load_status=0
    local config_path

    if tadk_config_load "$project_root"; then
        return 0
    else
        load_status=$?
    fi

    if (( load_status == 1 )); then
        config_path="$(tadk_config_path "$project_root")" ||
            return $?

        tadk_error "项目配置不存在：$config_path"
    fi

    return "$load_status"
}

show_config() {
    if (( $# != 1 )); then
        tadk_error '内部错误：show_config 需要 PROJECT_ROOT'
        return 64
    fi

    local project_root="$1"
    local config_path

    load_project_config "$project_root" ||
        return $?

    config_path="$(tadk_config_path "$project_root")" ||
        return $?

    tadk_heading "TADK Project Config"
    tadk_separator
    printf '项目：%s\n' "$project_root"
    printf '配置：%s\n' "$config_path"
    printf '版本：%s\n' "$TADK_CONFIG_VERSION"
    printf '模块：%s\n' "$TADK_CONFIG_MODULE"
    printf '变体：%s\n' "$TADK_CONFIG_VARIANT"
    tadk_separator
}

validate_config() {
    if (( $# != 1 )); then
        tadk_error '内部错误：validate_config 需要 PROJECT_ROOT'
        return 64
    fi

    local project_root="$1"
    local config_path

    load_project_config "$project_root" ||
        return $?

    config_path="$(tadk_config_path "$project_root")" ||
        return $?

    tadk_success "项目配置有效：$config_path"
    printf 'Module: %s\n' "$TADK_CONFIG_MODULE"
    printf 'Variant: %s\n' "$TADK_CONFIG_VARIANT"
}

while (( $# > 0 )); do
    case "$1" in
        show|validate)
            if [[ -n "$ACTION" ]]; then
                tadk_error "config 只能指定一个子命令"
                usage >&2
                exit 64
            fi

            ACTION="$1"
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        -*)
            tadk_error "未知参数：$1"
            usage >&2
            exit 64
            ;;

        *)
            if [[ -z "$ACTION" ]]; then
                tadk_error "未知 config 子命令：$1"
                usage >&2
                exit 64
            fi

            if [[ -n "$PROJECT_PATH" ]]; then
                tadk_error "config 最多接受一个项目目录参数"
                usage >&2
                exit 64
            fi

            PROJECT_PATH="$1"
            ;;
    esac

    shift
done

if [[ -z "$ACTION" ]]; then
    tadk_error "缺少 config 子命令"
    usage >&2
    exit 64
fi

PROJECT_ROOT="$(resolve_project_root)" ||
    exit $?

case "$ACTION" in
    show)
        show_config "$PROJECT_ROOT"
        ;;

    validate)
        validate_config "$PROJECT_ROOT"
        ;;
esac
