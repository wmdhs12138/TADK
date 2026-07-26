#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$TADK_ROOT/lib/common.sh"
source "$TADK_ROOT/lib/adb.sh"

ACTION="connect"
ADDRESS=""
PAIRING_CODE=""

usage() {
    tadk_print_help 'help.connect'
}

validate_address() {
    if (( $# != 1 )); then
        tadk_error \
            "内部错误：validate_address 需要 ADDRESS"
        return 64
    fi

    local address="$1"
    local port=""

    [[ -n "$address" ]] || {
        tadk_error "$(tadk_text 'connect.address_empty')"
        return 64
    }

    [[ "$address" != *[[:space:]]* ]] || {
        tadk_error "$(tadk_text 'connect.address_whitespace' "$address")"
        return 64
    }

    if [[ "$address" =~ ^[^:]+:([0-9]+)$ ]]; then
        port="${BASH_REMATCH[1]}"
    elif [[ "$address" =~ ^\[[^]]+\]:([0-9]+)$ ]]; then
        port="${BASH_REMATCH[1]}"
    else
        tadk_error "$(tadk_text 'connect.address_invalid' "$address")"
        tadk_text 'connect.address_format'
        printf '\n'
        return 64
    fi

    if (( 10#$port < 1 || 10#$port > 65535 )); then
        tadk_error "$(tadk_text 'connect.port_invalid' "$port")"
        return 64
    fi
}

print_devices() {
    local devices_output=""

    printf '\n'
    tadk_heading "$(tadk_text 'connect.devices_heading')"
    tadk_separator

    devices_output="$(adb devices -l)"

    printf '%s\n' "$devices_output"

    if ! printf '%s\n' "$devices_output" |
        sed '1d' |
        grep -q '[^[:space:]]'; then
        tadk_warn "$(tadk_text 'connect.no_devices')"
    fi
}

connect_device() {
    local output=""
    local status=0

    tadk_info "$(tadk_text 'connect.connecting' "$ADDRESS")"

    set +e
    output="$(adb connect "$ADDRESS" 2>&1)"
    status=$?
    set -e

    printf '%s\n' "$output"

    if (( status != 0 )); then
        tadk_error "ADB 连接失败"
        return "$status"
    fi

    if [[ "$output" == *"connected to "* ||
          "$output" == *"already connected to "* ]]; then
        tadk_success "ADB 连接成功"
        return 0
    fi

    tadk_warn "$(tadk_text 'connect.command_completed')"
}

pair_device() {
    local output=""
    local status=0

    tadk_info "$(tadk_text 'connect.pairing' "$ADDRESS")"

    set +e

    if [[ -n "$PAIRING_CODE" ]]; then
        output="$(
            printf '%s\n' "$PAIRING_CODE" |
                adb pair "$ADDRESS" 2>&1
        )"
        status=$?
    else
        adb pair "$ADDRESS"
        status=$?
    fi

    set -e

    if [[ -n "$PAIRING_CODE" ]]; then
        printf '%s\n' "$output"
    fi

    if (( status != 0 )); then
        tadk_error "ADB 配对失败"
        return "$status"
    fi

    tadk_success "ADB 配对完成"
    tadk_text 'connect.pair_next'
    printf '\n'
    printf '  tadk connect HOST:PORT\n'
}

disconnect_device() {
    local output=""
    local status=0

    tadk_info "$(tadk_text 'connect.disconnecting' "$ADDRESS")"

    set +e
    output="$(adb disconnect "$ADDRESS" 2>&1)"
    status=$?
    set -e

    printf '%s\n' "$output"

    if (( status != 0 )); then
        tadk_error "ADB 断开失败"
        return "$status"
    fi

    tadk_success "ADB 设备已断开"
}

disconnect_all_devices() {
    local output=""
    local status=0

    tadk_info "$(tadk_text 'connect.disconnecting_all')"

    set +e
    output="$(adb disconnect 2>&1)"
    status=$?
    set -e

    printf '%s\n' "$output"

    if (( status != 0 )); then
        tadk_error "ADB 断开失败"
        return "$status"
    fi

    tadk_success "TCP/IP ADB 连接已断开"
}

while (( $# > 0 )); do
    case "$1" in
        --pair)
            [[ "$ACTION" == "connect" && -z "$ADDRESS" ]] ||
                tadk_die "只能指定一种连接操作"

            ACTION="pair"
            shift

            (( $# > 0 )) ||
                tadk_die "--pair 缺少配对地址"

            ADDRESS="$1"

            if (( $# > 1 )) &&
                [[ "${2:-}" != -* ]]; then
                shift
                PAIRING_CODE="$1"
            fi
            ;;

        --disconnect)
            [[ "$ACTION" == "connect" && -z "$ADDRESS" ]] ||
                tadk_die "只能指定一种连接操作"

            ACTION="disconnect"
            shift

            (( $# > 0 )) ||
                tadk_die "--disconnect 缺少设备地址"

            ADDRESS="$1"
            ;;

        --disconnect-all)
            [[ "$ACTION" == "connect" && -z "$ADDRESS" ]] ||
                tadk_die "只能指定一种连接操作"

            ACTION="disconnect-all"
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        -*)
            tadk_die "未知参数：$1"
            ;;

        *)
            if [[ "$ACTION" != "connect" || -n "$ADDRESS" ]]; then
                tadk_die "多余参数：$1"
            fi

            ADDRESS="$1"
            ;;
    esac

    shift
done

tadk_adb_require_command

case "$ACTION" in
    connect)
        [[ -n "$ADDRESS" ]] || {
            usage
            exit 64
        }

        validate_address "$ADDRESS" ||
            exit $?

        if connect_device; then
            operation_status=0
        else
            operation_status=$?
        fi
        ;;

    pair)
        validate_address "$ADDRESS" ||
            exit $?

        if [[ -n "$PAIRING_CODE" &&
              ! "$PAIRING_CODE" =~ ^[0-9]+$ ]]; then
            tadk_die "配对码只能包含数字"
        fi

        if pair_device; then
            operation_status=0
        else
            operation_status=$?
        fi
        ;;

    disconnect)
        validate_address "$ADDRESS" ||
            exit $?

        if disconnect_device; then
            operation_status=0
        else
            operation_status=$?
        fi
        ;;

    disconnect-all)
        if disconnect_all_devices; then
            operation_status=0
        else
            operation_status=$?
        fi
        ;;

    *)
        tadk_die "内部错误：未知连接操作 $ACTION"
        ;;
esac

print_devices

exit "$operation_status"
