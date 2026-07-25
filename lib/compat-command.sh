#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $# -lt 2 ]]; then
    printf '用法：compat-command.sh <tadk-root> <command> [args...]\n' >&2
    exit 64
fi

TADK_ROOT="$1"
COMMAND_NAME="$2"
shift 2

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/command.sh"

COMMAND_TARGET="$(
    tadk_command_target "$TADK_ROOT" "$COMMAND_NAME" || true
)"

if [[ -z "$COMMAND_TARGET" ]]; then
    tadk_die "兼容命令不存在：$COMMAND_NAME"
fi

if [[ ! -x "$COMMAND_TARGET" ]]; then
    tadk_die "兼容命令不可执行：${COMMAND_TARGET#"$TADK_ROOT"/}"
fi

exec "$COMMAND_TARGET" "$@"
