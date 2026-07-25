#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$HOME/.cache/tadk/connect-command-test-$$"
MOCK_BIN="$TEST_ROOT/bin"
MOCK_LOG="$TEST_ROOT/adb.log"
MOCK_DEVICES="$TEST_ROOT/devices"

cleanup() {
    rm -rf "$TEST_ROOT"
}

trap cleanup EXIT

mkdir -p "$MOCK_BIN"
: > "$MOCK_LOG"

cat > "$MOCK_DEVICES" <<'DEVICES'
List of devices attached
192.168.1.8:37123	device product:mock model:Mock_Device
DEVICES

cat > "$MOCK_BIN/adb" <<'MOCK_ADB'
#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

printf 'adb' >> "$MOCK_LOG"

for argument in "$@"; do
    printf ' %q' "$argument" >> "$MOCK_LOG"
done

printf '\n' >> "$MOCK_LOG"

case "${1:-}" in
    connect)
        printf 'connected to %s\n' "${2:-}"
        ;;

    pair)
        read -r pairing_code || true

        if [[ -n "${pairing_code:-}" ]]; then
            printf 'Successfully paired to %s\n' "${2:-}"
        else
            printf 'Enter pairing code: Successfully paired to %s\n' \
                "${2:-}"
        fi
        ;;

    disconnect)
        if [[ -n "${2:-}" ]]; then
            printf 'disconnected %s\n' "$2"
        else
            printf 'disconnected everything\n'
        fi
        ;;

    devices)
        cat "$MOCK_DEVICES"
        ;;

    *)
        printf 'Unsupported adb command: %s\n' "${1:-}" >&2
        exit 1
        ;;
esac
MOCK_ADB

chmod +x "$MOCK_BIN/adb"

export MOCK_LOG
export MOCK_DEVICES
export PATH="$MOCK_BIN:$PATH"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local value="$1"
    local expected="$2"
    local message="$3"

    [[ "$value" == *"$expected"* ]] ||
        fail "$message"
}

assert_failure() {
    local status="$1"
    local message="$2"

    (( status != 0 )) ||
        fail "$message"
}

reset_log() {
    : > "$MOCK_LOG"
}

printf 'TEST help succeeds\n'

output="$("$TADK_ROOT/bin/tadk" connect --help 2>&1)"

assert_contains \
    "$output" \
    "tadk connect --pair ADDRESS" \
    "帮助应包含配对用法"

assert_contains \
    "$output" \
    "tadk connect --disconnect ADDRESS" \
    "帮助应包含断开用法"

printf 'PASS help succeeds\n\n'

printf 'TEST connect device\n'

reset_log

output="$(
    "$TADK_ROOT/bin/tadk" \
        connect \
        192.168.1.8:37123 \
        2>&1
)"

assert_contains \
    "$output" \
    "ADB 连接成功" \
    "连接成功时应显示成功信息"

assert_contains \
    "$output" \
    "192.168.1.8:37123" \
    "连接后应显示当前设备"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb connect 192.168.1.8:37123" \
    "应调用 adb connect"

assert_contains \
    "$calls" \
    "adb devices -l" \
    "连接后应刷新设备状态"

printf 'PASS connect device\n\n'

printf 'TEST pair device with code\n'

reset_log

output="$(
    "$TADK_ROOT/bin/tadk" \
        connect \
        --pair \
        192.168.1.8:41237 \
        123456 \
        2>&1
)"

assert_contains \
    "$output" \
    "ADB 配对完成" \
    "配对成功时应显示成功信息"

assert_contains \
    "$output" \
    "tadk connect HOST:PORT" \
    "配对后应提示继续连接"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb pair 192.168.1.8:41237" \
    "应调用 adb pair"

printf 'PASS pair device with code\n\n'

printf 'TEST disconnect one device\n'

reset_log

output="$(
    "$TADK_ROOT/bin/tadk" \
        connect \
        --disconnect \
        192.168.1.8:37123 \
        2>&1
)"

assert_contains \
    "$output" \
    "ADB 设备已断开" \
    "断开成功时应显示成功信息"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb disconnect 192.168.1.8:37123" \
    "应断开指定地址"

printf 'PASS disconnect one device\n\n'

printf 'TEST disconnect all devices\n'

reset_log

output="$(
    "$TADK_ROOT/bin/tadk" \
        connect \
        --disconnect-all \
        2>&1
)"

assert_contains \
    "$output" \
    "TCP/IP ADB 连接已断开" \
    "全部断开时应显示成功信息"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb disconnect" \
    "应调用无地址的 adb disconnect"

printf 'PASS disconnect all devices\n\n'

printf 'TEST missing address fails\n'

set +e
output="$("$TADK_ROOT/bin/tadk" connect 2>&1)"
status=$?
set -e

assert_failure \
    "$status" \
    "缺少连接地址时应失败"

assert_contains \
    "$output" \
    "用法：" \
    "缺少地址时应显示帮助"

printf 'PASS missing address fails\n\n'

printf 'TEST invalid address fails\n'

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        connect \
        invalid-address \
        2>&1
)"
status=$?
set -e

assert_failure \
    "$status" \
    "无效地址应失败"

assert_contains \
    "$output" \
    "无效的 ADB 地址" \
    "应说明地址格式无效"

printf 'PASS invalid address fails\n\n'

printf 'TEST invalid port fails\n'

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        connect \
        192.168.1.8:70000 \
        2>&1
)"
status=$?
set -e

assert_failure \
    "$status" \
    "越界端口应失败"

assert_contains \
    "$output" \
    "无效的 ADB 端口" \
    "应说明端口无效"

printf 'PASS invalid port fails\n\n'

printf 'TEST pairing code must be numeric\n'

set +e
output="$(
    "$TADK_ROOT/bin/tadk" \
        connect \
        --pair \
        192.168.1.8:41237 \
        abc123 \
        2>&1
)"
status=$?
set -e

assert_failure \
    "$status" \
    "非数字配对码应失败"

assert_contains \
    "$output" \
    "配对码只能包含数字" \
    "应说明配对码格式"

printf 'PASS pairing code must be numeric\n\n'
printf 'PASS: connect command integration\n'
