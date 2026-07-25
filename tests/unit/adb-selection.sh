#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$HOME/.cache/tadk/adb-selection-test-$$"
MOCK_BIN="$TEST_ROOT/bin"
MOCK_MODE_FILE="$TEST_ROOT/mode"
MOCK_LOG="$TEST_ROOT/adb.log"

cleanup() {
    rm -rf "$TEST_ROOT"
}

trap cleanup EXIT

mkdir -p "$MOCK_BIN"
: > "$MOCK_LOG"

cat > "$MOCK_BIN/adb" <<'MOCK_ADB'
#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

printf 'adb' >> "$MOCK_LOG"

for argument in "$@"; do
    printf ' %q' "$argument" >> "$MOCK_LOG"
done

printf '\n' >> "$MOCK_LOG"

selected_serial=""

if [[ "${1:-}" == "-s" ]]; then
    selected_serial="${2:-}"
    shift 2
fi

command_name="${1:-}"
shift || true

mode="$(cat "$MOCK_MODE_FILE")"

case "$command_name" in
    get-state)
        case "$mode" in
            default-ready)
                printf 'device\n'
                ;;

            one-ready)
                if [[ "$selected_serial" == "SERIAL_ONE" ]]; then
                    printf 'device\n'
                else
                    printf \
                        'error: more than one device/emulator\n' \
                        >&2
                    exit 1
                fi
                ;;

            multiple-ready)
                printf \
                    'error: more than one device/emulator\n' \
                    >&2
                exit 1
                ;;

            none-ready)
                printf \
                    'error: no devices/emulators found\n' \
                    >&2
                exit 1
                ;;

            explicit-offline)
                printf 'offline\n'
                ;;

            *)
                printf 'unsupported mode: %s\n' "$mode" >&2
                exit 1
                ;;
        esac
        ;;

    devices)
        case "$mode" in
            one-ready)
                cat <<'DEVICES'
List of devices attached
SERIAL_ONE	device
SERIAL_UNAUTHORIZED	unauthorized
DEVICES
                ;;

            multiple-ready)
                cat <<'DEVICES'
List of devices attached
SERIAL_ONE	device
SERIAL_TWO	device
SERIAL_OFFLINE	offline
DEVICES
                ;;

            none-ready)
                cat <<'DEVICES'
List of devices attached
SERIAL_UNAUTHORIZED	unauthorized
SERIAL_OFFLINE	offline
DEVICES
                ;;

            *)
                printf 'List of devices attached\n'
                ;;
        esac
        ;;

    *)
        printf 'unsupported adb command: %s\n' "$command_name" >&2
        exit 1
        ;;
esac
MOCK_ADB

chmod +x "$MOCK_BIN/adb"

export MOCK_MODE_FILE
export MOCK_LOG
export PATH="$MOCK_BIN:$PATH"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/adb.sh"

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

assert_equals() {
    local actual="$1"
    local expected="$2"
    local message="$3"

    [[ "$actual" == "$expected" ]] ||
        fail "$message: expected=$expected actual=$actual"
}

reset_state() {
    TADK_ADB_SERIAL=""
    export TADK_ADB_SERIAL
    : > "$MOCK_LOG"
}

printf 'TEST default ADB target remains unchanged\n'

reset_state
printf 'default-ready\n' > "$MOCK_MODE_FILE"

tadk_adb_require_device

assert_equals \
    "$TADK_ADB_SERIAL" \
    "" \
    "默认设备可用时不应写入序列号"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb get-state" \
    "应先检查默认 ADB 目标"

if [[ "$calls" == *"adb devices"* ]]; then
    fail "默认设备可用时不应扫描设备列表"
fi

printf 'PASS default ADB target remains unchanged\n\n'

printf 'TEST unique ready device is selected\n'

reset_state
printf 'one-ready\n' > "$MOCK_MODE_FILE"

tadk_adb_require_device

assert_equals \
    "$TADK_ADB_SERIAL" \
    "SERIAL_ONE" \
    "应自动选择唯一可用设备"

calls="$(cat "$MOCK_LOG")"

assert_contains \
    "$calls" \
    "adb devices" \
    "默认目标不可确定时应扫描设备"

assert_contains \
    "$calls" \
    "adb -s SERIAL_ONE get-state" \
    "应验证自动选择的设备"

printf 'PASS unique ready device is selected\n\n'

printf 'TEST multiple ready devices require explicit selection\n'

reset_state
printf 'multiple-ready\n' > "$MOCK_MODE_FILE"

set +e
output="$(tadk_adb_require_device 2>&1)"
status=$?
set -e

(( status != 0 )) ||
    fail "多个可用设备时应失败"

assert_contains \
    "$output" \
    "检测到多个可用 ADB 设备" \
    "应说明存在多个设备"

assert_contains \
    "$output" \
    "SERIAL_ONE" \
    "应列出第一台设备"

assert_contains \
    "$output" \
    "SERIAL_TWO" \
    "应列出第二台设备"

assert_contains \
    "$output" \
    "--device SERIAL" \
    "应提示显式选择设备"

printf 'PASS multiple ready devices require explicit selection\n\n'

printf 'TEST no ready device fails clearly\n'

reset_state
printf 'none-ready\n' > "$MOCK_MODE_FILE"

set +e
output="$(tadk_adb_require_device 2>&1)"
status=$?
set -e

(( status != 0 )) ||
    fail "没有可用设备时应失败"

assert_contains \
    "$output" \
    "未发现已连接并授权的 ADB 设备" \
    "应说明没有授权设备"

printf 'PASS no ready device fails clearly\n\n'

printf 'TEST explicit unavailable device does not fall back\n'

reset_state
printf 'explicit-offline\n' > "$MOCK_MODE_FILE"
tadk_adb_set_serial "EXPLICIT_DEVICE"

set +e
output="$(tadk_adb_require_device 2>&1)"
status=$?
set -e

(( status != 0 )) ||
    fail "显式离线设备时应失败"

assert_contains \
    "$output" \
    "指定的 ADB 设备不可用：EXPLICIT_DEVICE" \
    "应指出显式设备不可用"

calls="$(cat "$MOCK_LOG")"

if [[ "$calls" == *"adb devices"* ]]; then
    fail "显式设备不可用时不应回退扫描其他设备"
fi

printf 'PASS explicit unavailable device does not fall back\n\n'
printf 'PASS: ADB automatic device selection unit tests\n'
