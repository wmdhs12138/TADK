#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/test.sh"

TEST_SUITE="all"

usage() {
    cat <<'HELP'
用法：
  tadk test [suite]

说明：
  运行 TADK 自身的测试套件。

测试套件：
  all                 运行全部测试（默认）
  unit                只运行单元测试
  smoke               只运行冒烟测试
  integration         只运行集成测试

其他：
  -h, --help          显示帮助

示例：
  tadk test
  tadk test all
  tadk test unit
  tadk test smoke
  tadk test integration
HELP
}

if (( $# > 1 )); then
    tadk_error "test 最多接受一个测试套件参数"
    usage >&2
    exit 64
fi

if (( $# == 1 )); then
    case "$1" in
        all|unit|smoke|integration)
            TEST_SUITE="$1"
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            tadk_error "未知测试套件：$1"
            usage >&2
            exit 64
            ;;
    esac
fi

case "$TEST_SUITE" in
    all)
        test_run_all "$TADK_ROOT"
        ;;

    unit)
        test_run_unit "$TADK_ROOT"
        ;;

    smoke)
        test_run_smoke "$TADK_ROOT"
        ;;

    integration)
        test_run_integration "$TADK_ROOT"
        ;;
esac
