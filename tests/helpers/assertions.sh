#!/data/data/com.termux/files/usr/bin/bash

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-值不相等}"

    if [[ "$actual" != "$expected" ]]; then
        printf 'ASSERT EQUALS FAILED: %s\n' "$message" >&2
        printf 'expected: %q\n' "$expected" >&2
        printf 'actual:   %q\n' "$actual" >&2
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-未找到预期内容}"

    if [[ "$haystack" != *"$needle"* ]]; then
        printf 'ASSERT CONTAINS FAILED: %s\n' "$message" >&2
        printf 'needle: %q\n' "$needle" >&2
        printf 'output:\n%s\n' "$haystack" >&2
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-包含了不应出现的内容}"

    if [[ "$haystack" == *"$needle"* ]]; then
        printf 'ASSERT NOT CONTAINS FAILED: %s\n' "$message" >&2
        printf 'needle: %q\n' "$needle" >&2
        printf 'output:\n%s\n' "$haystack" >&2
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        printf 'ASSERT FILE EXISTS FAILED: %s\n' \
            "$file_path" >&2
        return 1
    fi
}

assert_success() {
    local exit_code="$1"
    local message="${2:-命令应成功}"

    if (( exit_code != 0 )); then
        printf 'ASSERT SUCCESS FAILED: %s\n' \
            "$message" >&2
        printf 'exit code: %s\n' "$exit_code" >&2
        return 1
    fi
}

assert_failure() {
    local exit_code="$1"
    local message="${2:-命令应失败}"

    if (( exit_code == 0 )); then
        printf 'ASSERT FAILURE FAILED: %s\n' \
            "$message" >&2
        return 1
    fi
}
