#!/data/data/com.termux/files/usr/bin/bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    printf '\033[32m✓\033[0m %s\n' "$1"
    ((PASS_COUNT += 1))
}

fail() {
    printf '\033[31m✗\033[0m %s\n' "$1" >&2
    ((FAIL_COUNT += 1))
}

run_test() {
    local name="$1"
    shift

    if "$@" >/dev/null 2>&1; then
        pass "$name"
    else
        fail "$name"
    fi
}

printf '\n\033[1mTADK Smoke Tests\033[0m\n'
printf '%s\n' '========================================'

printf '\n\033[1mShell syntax\033[0m\n'
printf '%s\n' '----------------------------------------'

while IFS= read -r file; do
    relative="${file#"$TADK_ROOT"/}"

    if bash -n "$file"; then
        pass "$relative"
    else
        fail "$relative"
    fi
done < <(
    find \
        "$TADK_ROOT/bin" \
        "$TADK_ROOT/lib" \
        "$TADK_ROOT/commands" \
        -maxdepth 2 \
        -type f \
        2>/dev/null |
        sort
)

printf '\n\033[1mCLI commands\033[0m\n'
printf '%s\n' '----------------------------------------'

run_test "command manifest" \
    bash -c "
        source '$TADK_ROOT/lib/common.sh'
        source '$TADK_ROOT/lib/command.sh'
        tadk_command_validate_manifest '$TADK_ROOT'
    "

run_test "tadk info --help" \
    "$TADK_ROOT/bin/tadk" info --help

run_test "compat bin/info --help" \
    "$TADK_ROOT/bin/info" --help

run_test "tadk clean --help" \
    "$TADK_ROOT/bin/tadk" clean --help

run_test "compat bin/clean --help" \
    "$TADK_ROOT/bin/clean" --help

run_test "compat bin/doctor --help" \
    "$TADK_ROOT/bin/doctor" --help

run_test "tadk --help" \
    "$TADK_ROOT/bin/tadk" --help

run_test "tadk --version" \
    "$TADK_ROOT/bin/tadk" --version

run_test "doctor --help" \
    "$TADK_ROOT/bin/doctor" --help

run_test "run --help" \
    "$TADK_ROOT/bin/run" --help

run_test "clean --help" \
    "$TADK_ROOT/bin/clean" --help

run_test "info --help" \
    "$TADK_ROOT/bin/info" --help

run_test "clean implementation exists" \
    test -x "$TADK_ROOT/commands/clean.sh"

run_test "doctor implementation exists" \
    test -x "$TADK_ROOT/commands/doctor.sh"

printf '\n%s\n' '========================================'
printf '通过：%d\n' "$PASS_COUNT"
printf '失败：%d\n' "$FAIL_COUNT"

if (( FAIL_COUNT > 0 )); then
    printf '\n\033[31m冒烟测试失败。\033[0m\n' >&2
    exit 1
fi

printf '\n\033[32m全部冒烟测试通过。\033[0m\n'
