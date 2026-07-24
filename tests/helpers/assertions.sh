#!/data/data/com.termux/files/usr/bin/bash

assert_equals() {
    local expected="$1" actual="$2" message="${3:-值不相等}"
    if [[ "$actual" != "$expected" ]]; then
        printf 'ASSERT EQUALS FAILED: %s\nexpected: %q\nactual:   %q\n' "$message" "$expected" "$actual" >&2
        return 1
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" message="${3:-未找到预期内容}"
    if [[ "$haystack" != *"$needle"* ]]; then
        printf 'ASSERT CONTAINS FAILED: %s\nneedle: %q\noutput:\n%s\n' "$message" "$needle" "$haystack" >&2
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1" needle="$2" message="${3:-包含了不应出现的内容}"
    if [[ "$haystack" == *"$needle"* ]]; then
        printf 'ASSERT NOT CONTAINS FAILED: %s\nneedle: %q\noutput:\n%s\n' "$message" "$needle" "$haystack" >&2
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1" message="${2:-文件应存在}"
    if [[ ! -f "$file_path" ]]; then
        printf 'ASSERT FILE EXISTS FAILED: %s\nfile: %s\n' "$message" "$file_path" >&2
        return 1
    fi
}

assert_file_not_exists() {
    local file_path="$1" message="${2:-文件不应存在}"
    if [[ -e "$file_path" ]]; then
        printf 'ASSERT FILE NOT EXISTS FAILED: %s\nfile: %s\n' "$message" "$file_path" >&2
        return 1
    fi
}

assert_success() {
    local exit_code="$1" message="${2:-命令应成功}"
    if (( exit_code != 0 )); then
        printf 'ASSERT SUCCESS FAILED: %s\nexit code: %s\n' "$message" "$exit_code" >&2
        return 1
    fi
}

assert_failure() {
    local exit_code="$1" message="${2:-命令应失败}"
    if (( exit_code == 0 )); then
        printf 'ASSERT FAILURE FAILED: %s\n' "$message" >&2
        return 1
    fi
}

assert_order() {
    local haystack="$1" first="$2" second="$3" message="${4:-内容顺序不正确}"
    local before_first="${haystack%%"$first"*}"
    local before_second="${haystack%%"$second"*}"
    if [[ "$haystack" != *"$first"* || "$haystack" != *"$second"* || ${#before_first} -ge ${#before_second} ]]; then
        printf 'ASSERT ORDER FAILED: %s\nfirst: %q\nsecond: %q\noutput:\n%s\n' "$message" "$first" "$second" "$haystack" >&2
        return 1
    fi
}
