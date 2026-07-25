#!/usr/bin/env bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../helpers/assertions.sh
source "$TADK_ROOT/tests/helpers/assertions.sh"

PASSED=0
FAILED=0

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

create_fake_root() {
    local root="$1"

    mkdir -p \
        "$root/tests/unit" \
        "$root/tests/integration"

    cat > "$root/tests/unit/run.sh" <<'RUNNER'
#!/usr/bin/env bash
printf 'unit-runner\n'
RUNNER

    cat > "$root/tests/smoke.sh" <<'RUNNER'
#!/usr/bin/env bash
printf 'smoke-runner\n'
RUNNER

    cat > "$root/tests/integration/run.sh" <<'RUNNER'
#!/usr/bin/env bash
printf 'integration-runner\n'
RUNNER

    chmod +x \
        "$root/tests/unit/run.sh" \
        "$root/tests/smoke.sh" \
        "$root/tests/integration/run.sh"
}

case_unit_requires_one_argument() {
    source "$TADK_ROOT/lib/test.sh"

    local output status=0
    output="$(test_run_unit 2>&1)" || status=$?

    assert_equals '64' "$status"
    assert_contains "$output" 'usage: test_run_unit TADK_ROOT'
}

case_missing_root_fails() {
    source "$TADK_ROOT/lib/test.sh"

    local output status=0
    output="$(test_run_unit '/path/that/does/not/exist' 2>&1)" ||
        status=$?

    assert_equals '1' "$status"
    assert_contains "$output" 'TADK root does not exist'
}

case_missing_runner_fails() {
    source "$TADK_ROOT/lib/test.sh"

    local fake_root output status=0
    fake_root="$(mktemp -d)"
    trap 'rm -rf "$fake_root"' RETURN

    output="$(test_run_unit "$fake_root" 2>&1)" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" 'test runner does not exist'
    assert_contains "$output" '/tests/unit/run.sh'
}

case_unit_runner_executes() {
    source "$TADK_ROOT/lib/test.sh"

    local fake_root output status=0
    fake_root="$(mktemp -d)"
    trap 'rm -rf "$fake_root"' RETURN

    create_fake_root "$fake_root"

    output="$(test_run_unit "$fake_root" 2>&1)" || status=$?

    assert_success "$status"
    assert_contains "$output" 'Running unit tests...'
    assert_contains "$output" 'unit-runner'
    assert_contains "$output" 'unit tests passed'
}

case_smoke_runner_executes() {
    source "$TADK_ROOT/lib/test.sh"

    local fake_root output status=0
    fake_root="$(mktemp -d)"
    trap 'rm -rf "$fake_root"' RETURN

    create_fake_root "$fake_root"

    output="$(test_run_smoke "$fake_root" 2>&1)" || status=$?

    assert_success "$status"
    assert_contains "$output" 'Running smoke tests...'
    assert_contains "$output" 'smoke-runner'
    assert_contains "$output" 'smoke tests passed'
}

case_integration_runner_executes() {
    source "$TADK_ROOT/lib/test.sh"

    local fake_root output status=0
    fake_root="$(mktemp -d)"
    trap 'rm -rf "$fake_root"' RETURN

    create_fake_root "$fake_root"

    output="$(test_run_integration "$fake_root" 2>&1)" || status=$?

    assert_success "$status"
    assert_contains "$output" 'Running integration tests...'
    assert_contains "$output" 'integration-runner'
    assert_contains "$output" 'integration tests passed'
}

case_runner_failure_is_propagated() {
    source "$TADK_ROOT/lib/test.sh"

    local fake_root output status=0
    fake_root="$(mktemp -d)"
    trap 'rm -rf "$fake_root"' RETURN

    create_fake_root "$fake_root"

    cat > "$fake_root/tests/unit/run.sh" <<'RUNNER'
#!/usr/bin/env bash
printf 'unit-failure\n'
exit 23
RUNNER

    chmod +x "$fake_root/tests/unit/run.sh"

    output="$(test_run_unit "$fake_root" 2>&1)" || status=$?

    assert_equals '23' "$status"
    assert_contains "$output" 'unit-failure'
    assert_contains "$output" 'unit tests failed'
}

case_all_runs_in_order() {
    source "$TADK_ROOT/lib/test.sh"

    local fake_root output status=0
    fake_root="$(mktemp -d)"
    trap 'rm -rf "$fake_root"' RETURN

    create_fake_root "$fake_root"

    output="$(test_run_all "$fake_root" 2>&1)" || status=$?

    assert_success "$status"
    assert_order "$output" 'unit-runner' 'smoke-runner'
    assert_order "$output" 'smoke-runner' 'integration-runner'
    assert_contains "$output" 'All tests passed'
}

case_all_stops_after_unit_failure() {
    source "$TADK_ROOT/lib/test.sh"

    local fake_root output status=0
    fake_root="$(mktemp -d)"
    trap 'rm -rf "$fake_root"' RETURN

    create_fake_root "$fake_root"

    cat > "$fake_root/tests/unit/run.sh" <<'RUNNER'
#!/usr/bin/env bash
printf 'unit-failure\n'
exit 31
RUNNER

    chmod +x "$fake_root/tests/unit/run.sh"

    output="$(test_run_all "$fake_root" 2>&1)" || status=$?

    assert_equals '31' "$status"
    assert_contains "$output" 'unit-failure'
    assert_not_contains "$output" 'smoke-runner'
    assert_not_contains "$output" 'integration-runner'
}

case_all_stops_after_smoke_failure() {
    source "$TADK_ROOT/lib/test.sh"

    local fake_root output status=0
    fake_root="$(mktemp -d)"
    trap 'rm -rf "$fake_root"' RETURN

    create_fake_root "$fake_root"

    cat > "$fake_root/tests/smoke.sh" <<'RUNNER'
#!/usr/bin/env bash
printf 'smoke-failure\n'
exit 32
RUNNER

    chmod +x "$fake_root/tests/smoke.sh"

    output="$(test_run_all "$fake_root" 2>&1)" || status=$?

    assert_equals '32' "$status"
    assert_contains "$output" 'unit-runner'
    assert_contains "$output" 'smoke-failure'
    assert_not_contains "$output" 'integration-runner'
}

run_case \
    'unit requires one argument' \
    case_unit_requires_one_argument

run_case \
    'missing root fails' \
    case_missing_root_fails

run_case \
    'missing runner fails' \
    case_missing_runner_fails

run_case \
    'unit runner executes' \
    case_unit_runner_executes

run_case \
    'smoke runner executes' \
    case_smoke_runner_executes

run_case \
    'integration runner executes' \
    case_integration_runner_executes

run_case \
    'runner failure is propagated' \
    case_runner_failure_is_propagated

run_case \
    'all suites run in order' \
    case_all_runs_in_order

run_case \
    'all stops after unit failure' \
    case_all_stops_after_unit_failure

run_case \
    'all stops after smoke failure' \
    case_all_stops_after_smoke_failure

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All test library unit tests passed.\n'
