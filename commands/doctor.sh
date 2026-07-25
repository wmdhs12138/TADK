#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/doctor.sh"

usage() {
    cat <<'HELP'
用法：
  tadk doctor [PROJECT_ROOT]

说明：
  检查 Termux Android 开发环境和 Android 项目配置。

  未提供 PROJECT_ROOT 时，检查当前工作目录。

参数：
  PROJECT_ROOT          Android 项目根目录，默认为当前目录

选项：
  -h, --help            显示帮助

示例：
  tadk doctor
  tadk doctor .
  tadk doctor ~/projects/MyApp
HELP
}

if (( $# > 1 )); then
    tadk_error "doctor 最多接受一个项目目录参数"
    usage >&2
    exit 64
fi

PROJECT_ROOT="$PWD"

if (( $# == 1 )); then
    case "$1" in
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
            PROJECT_ROOT="$1"
            ;;
    esac
fi

if [[ -d "$PROJECT_ROOT" ]]; then
    PROJECT_ROOT="$(cd -- "$PROJECT_ROOT" && pwd)"
fi

doctor_run "$PROJECT_ROOT"
