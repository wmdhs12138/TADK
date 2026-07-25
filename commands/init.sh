#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/project.sh"
source "$TADK_ROOT/lib/init.sh"

FORCE=false
PROJECT_PATH=""
MODULE=""

usage() {
    cat <<'HELP'
用法：
  tadk init [选项] [PROJECT_ROOT]

说明：
  在已有 Gradle Android 项目中创建 TADK 项目配置。

  未提供 PROJECT_ROOT 时，从当前目录向上查找项目根目录。

选项：
  --force             覆盖已有的 .tadk/project.conf
  --module MODULE     指定 Android application 模块，例如 feature/chat
  -h, --help          显示帮助

参数：
  PROJECT_ROOT        Android 项目根目录或项目内的任意目录

生成文件：
  .tadk/project.conf

示例：
  tadk init
  tadk init --force
  tadk init --module mobile
  tadk init ~/projects/MyApp
  tadk init --module feature/chat ~/projects/MyApp
  tadk init --force ~/projects/MyApp
HELP
}

while (( $# > 0 )); do
    case "$1" in
        --force)
            FORCE=true
            ;;

        --module)
            shift

            [[ $# -gt 0 ]] ||
                tadk_die "--module 缺少模块名称" 64

            [[ -z "$MODULE" ]] ||
                tadk_die "--module 不能重复指定" 64

            MODULE="$1"
            ;;

        --module=*)
            [[ -z "$MODULE" ]] ||
                tadk_die "--module 不能重复指定" 64

            MODULE="${1#--module=}"

            [[ -n "$MODULE" ]] ||
                tadk_die "--module 缺少模块名称" 64
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
            if [[ -n "$PROJECT_PATH" ]]; then
                tadk_error "init 最多接受一个项目目录参数"
                usage >&2
                exit 64
            fi

            PROJECT_PATH="$1"
            ;;
    esac

    shift
done

if [[ -n "$PROJECT_PATH" ]]; then
    if [[ ! -d "$PROJECT_PATH" ]]; then
        tadk_error "项目目录不存在：$PROJECT_PATH"
        exit 1
    fi

    PROJECT_ROOT="$(
        tadk_find_project_root "$PROJECT_PATH"
    )" || {
        tadk_error "指定目录不在有效的 Gradle Android 项目中：$PROJECT_PATH"
        exit 1
    }
else
    PROJECT_ROOT="$(
        tadk_find_project_root "$PWD"
    )" || {
        tadk_error "当前目录不在有效的 Gradle Android 项目中"
        exit 1
    }
fi

tadk_heading "TADK Init"
tadk_separator
printf '项目：%s\n' "$PROJECT_ROOT"
printf '覆盖：%s\n' "$FORCE"
tadk_separator
printf '\n'

tadk_init_project "$PROJECT_ROOT" "$FORCE" "$MODULE"
