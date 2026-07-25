#!/data/data/com.termux/files/usr/bin/bash

set -uo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

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

case_help_succeeds() {
    local output status=0

    output="$("$TADK_ROOT/bin/tadk" doctor --help 2>&1)" ||
        status=$?

    assert_success "$status"
    assert_contains "$output" 'tadk doctor [PROJECT_ROOT]'
    assert_contains "$output" 'PROJECT_ROOT'
}

case_too_many_arguments_return_64() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" doctor one two 2>&1
    )" || status=$?

    assert_equals '64' "$status"
    assert_contains "$output" \
        'doctor 最多接受一个项目目录参数'
}

case_unknown_option_returns_64() {
    local output status=0

    output="$(
        "$TADK_ROOT/bin/tadk" doctor --unknown 2>&1
    )" || status=$?

    assert_equals '64' "$status"
    assert_contains "$output" '未知参数：--unknown'
}

case_missing_project_returns_1() {
    local missing_root output status=0

    missing_root="$(mktemp -u)"

    output="$(
        "$TADK_ROOT/bin/tadk" doctor "$missing_root" 2>&1
    )" || status=$?

    assert_equals '1' "$status"
    assert_contains "$output" 'project root does not exist'
    assert_contains "$output" "$missing_root"
}

case_relative_project_path_is_accepted() {
    local parent project output status=0

    parent="$(mktemp -d)"
    trap 'rm -rf "$parent"' RETURN

    project="$parent/project"

    mkdir -p \
        "$project/app/src/main" \
        "$project/app/build/outputs/apk" \
        "$project/android-sdk"

    cat > "$project/gradlew" <<'GRADLEW'
#!/usr/bin/env bash
exit 0
GRADLEW

    chmod +x "$project/gradlew"

    cat > "$project/app/src/main/AndroidManifest.xml" <<'MANIFEST'
<manifest package="com.example.app" />
MANIFEST

    output="$(
        cd "$parent" &&
        PREFIX='/data/data/com.termux/files/usr' \
        ANDROID_HOME="$project/android-sdk" \
        "$TADK_ROOT/bin/tadk" doctor project 2>&1
    )" || status=$?

    assert_contains "$output" 'TADK doctor'
    assert_contains "$output" \
        "Gradle Wrapper found: $project/gradlew"
    assert_contains "$output" \
        "Android manifest found: $project/app/src/main/AndroidManifest.xml"

    # 实际环境可能缺少 Java，因此这里只验证命令正确接受并规范化目录。
    if (( status != 0 && status != 1 )); then
        printf 'unexpected Doctor status: %s\n' "$status" >&2
        return 1
    fi
}

run_case \
    'help succeeds' \
    case_help_succeeds

run_case \
    'too many arguments return 64' \
    case_too_many_arguments_return_64

run_case \
    'unknown option returns 64' \
    case_unknown_option_returns_64

run_case \
    'missing project returns 1' \
    case_missing_project_returns_1

run_case \
    'relative project path is accepted' \
    case_relative_project_path_is_accepted

printf '%s\nPassed: %s\nFailed: %s\n' \
    '----------------------------------------' \
    "$PASSED" \
    "$FAILED"

(( FAILED == 0 )) || exit 1

printf 'All Doctor command integration tests passed.\n'
