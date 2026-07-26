#!/usr/bin/env bash

set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
    printf 'VERSION TEST FAILED: %s\n' "$1" >&2
    exit 1
}

version_file="$TADK_ROOT/VERSION"

[[ -f "$version_file" ]] ||
    fail "VERSION file is missing"

version="$(tr -d '\r\n' < "$version_file")"

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] ||
    fail "invalid version format: $version"

actual_version="$("$TADK_ROOT/bin/tadk" --version)"

[[ "$actual_version" == "TADK $version" ]] ||
    fail \
        "bin/tadk --version mismatch: expected 'TADK $version', got '$actual_version'"

grep -Fq \
    "Current development version: \`$version\`" \
    "$TADK_ROOT/README.md" ||
    fail "README.md does not reference the current version"

grep -Fq \
    "# TADK $version" \
    "$TADK_ROOT/RELEASE_NOTES.md" ||
    fail "RELEASE_NOTES.md does not reference the current version"

grep -Fq \
    "TADK $version" \
    "$TADK_ROOT/VERIFY.md" ||
    fail "VERIFY.md does not reference the current version"

grep -Fq \
    "## $version" \
    "$TADK_ROOT/CHANGELOG.md" ||
    fail "CHANGELOG.md does not contain the current release"

release_manifest="$TADK_ROOT/release/manifest.json"

[[ -f "$release_manifest" ]] ||
    fail "release/manifest.json is missing"

grep -Fq \
    '"version": "'"$version"'"' \
    "$release_manifest" ||
    fail "release/manifest.json does not reference the current version"

for package_contract_field in \
    '"version": 1' \
    '"full_archive": "TADK-{version}.zip"' \
    '"update_archive": "TADK-{version}-update.zip"' \
    '"root_directory": "TADK-{version}"' \
    '"checksum": "SHA-256"' \
    '"payload": "tracked-files"' \
    '"update_scope": "changed-tracked-files"' \
    '".git/"' \
    '".tadk/"'; do
    grep -Fq "$package_contract_field" "$release_manifest" ||
        fail "release package contract is missing: $package_contract_field"
done

printf 'PASS: version consistency\n'
