#!/usr/bin/env bash

set -uo pipefail

SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_WORK_ROOT="$HOME/.cache/tadk/tests/dev-variant-forwarding.$$"

source "$SOURCE_ROOT/tests/helpers/assertions.sh"

PASSED=0
FAILED=0

mkdir -p "$TEST_WORK_ROOT"

cleanup() {
    rm -rf "$TEST_WORK_ROOT"
}

trap cleanup EXIT HUP INT TERM

new_test_root() {
    mktemp -d "$TEST_WORK_ROOT/case.XXXXXX"
}

run_case() {
    local name="$1"
    shift

    printf 'TEST %s\n' "$name"

    if ( "$@" ); then
        PASSED=$((PASSED + 1))
        printf 'PASS %s\n\n' "$name"
    else
        FAILED=$((FAILED + 1))
        printf 'FAIL %s\n\n' "$name" >&2
    fi
}

write_recording_command() {
    local path="$1"
    local command_name="$2"

    cat > "$path" <<EOF_COMMAND
#!/usr/bin/env bash

set -Eeuo pipefail

printf '%s' '$command_name' >> "\$TADK_TEST_CALLS"

if (( \$# > 0 )); then
    printf ' %q' "\$@" >> "\$TADK_TEST_CALLS"
fi

printf '\\n' >> "\$TADK_TEST_CALLS"
EOF_COMMAND

    chmod +x "$path"
}

create_test_installation() {
    local root="$1"
    local tadk_root="$root/tadk"

    mkdir -p "$tadk_root"

    cp -a "$SOURCE_ROOT/." "$tadk_root/"

    rm -rf "$tadk_root/.git"

    write_recording_command \
        "$tadk_root/commands/build.sh" \
        build

    write_recording_command \
        "$tadk_root/commands/install.sh" \
        install

    write_recording_command \
        "$tadk_root/commands/launch.sh" \
        launch

    write_recording_command \
        "$tadk_root/commands/logcat.sh" \
        logcat

    chmod +x \
        "$tadk_root/bin/tadk" \
        "$tadk_root/commands/dev.sh"
}

run_dev() {
    local root="$1"
    shift

    TADK_TEST_CALLS="$root/calls.log" \
        "$root/tadk/bin/tadk" dev \
        --no-clear \
        --no-logcat \
        "$@"
}

read_calls() {
    local root="$1"

    assert_file_exists "$root/calls.log" ||
        return 1

    cat "$root/calls.log"
}

case_default_does_not_force_variant() {
    local root calls status=0

    root="$(new_test_root)" ||
        return 1

    create_test_installation "$root" ||
        return 1

    run_dev "$root" \
        >/dev/null 2>&1 ||
        status=$?

    assert_success "$status" ||
        return 1

    calls="$(read_calls "$root")" ||
        return 1

    assert_contains "$calls" "build" ||
        return 1

    assert_contains "$calls" "install" ||
        return 1

    assert_contains "$calls" "launch --restart" ||
        return 1

    assert_not_contains "$calls" "--debug" ||
        return 1

    assert_not_contains "$calls" "--release" ||
        return 1
}

case_debug_is_forwarded_to_build_and_install() {
    local root calls status=0

    root="$(new_test_root)" ||
        return 1

    create_test_installation "$root" ||
        return 1

    run_dev "$root" --debug \
        >/dev/null 2>&1 ||
        status=$?

    assert_success "$status" ||
        return 1

    calls="$(read_calls "$root")" ||
        return 1

    assert_contains "$calls" "build --debug" ||
        return 1

    assert_contains "$calls" "install --debug" ||
        return 1

    assert_not_contains "$calls" "--release" ||
        return 1
}

case_release_is_forwarded_to_build_and_install() {
    local root calls status=0

    root="$(new_test_root)" ||
        return 1

    create_test_installation "$root" ||
        return 1

    run_dev "$root" --release \
        >/dev/null 2>&1 ||
        status=$?

    assert_success "$status" ||
        return 1

    calls="$(read_calls "$root")" ||
        return 1

    assert_contains "$calls" "build --release" ||
        return 1

    assert_contains "$calls" "install --release" ||
        return 1

    assert_not_contains "$calls" "--debug" ||
        return 1
}

case_other_arguments_are_preserved() {
    local root calls status=0

    root="$(new_test_root)" ||
        return 1

    create_test_installation "$root" ||
        return 1

    run_dev \
        "$root" \
        --release \
        --clean \
        --no-cache \
        --rerun \
        --build-arg=--stacktrace \
        --install-arg=--user \
        --install-arg=0 \
        >/dev/null 2>&1 ||
        status=$?

    assert_success "$status" ||
        return 1

    calls="$(read_calls "$root")" ||
        return 1

    assert_contains "$calls" \
        "build --release --clean --no-cache --rerun -- --stacktrace" ||
        return 1

    assert_contains "$calls" \
        "install --release -- --user 0" ||
        return 1

    assert_contains "$calls" \
        "launch --restart" ||
        return 1
}

run_case \
    'default does not force variant' \
    case_default_does_not_force_variant

run_case \
    'debug is forwarded to build and install' \
    case_debug_is_forwarded_to_build_and_install

run_case \
    'release is forwarded to build and install' \
    case_release_is_forwarded_to_build_and_install

run_case \
    'other arguments are preserved' \
    case_other_arguments_are_preserved

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All dev variant forwarding integration tests passed.\n'
