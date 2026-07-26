#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TADK_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

PREVIOUS_REF=""
OUTPUT_DIR=""
FULL_ONLY=false

usage() {
    cat <<'HELP'
Usage:
  scripts/package-release.sh --previous-ref REF [--output-dir DIR]
  scripts/package-release.sh --full-only [--output-dir DIR]

Options:
  --previous-ref REF  Previous release commit or tag used for the update archive
  --output-dir DIR    Output directory for archives and checksums
  --full-only         Build only the full archive
  -h, --help          Show this help
HELP
}

die() {
    printf 'Error: %s\n' "$1" >&2
    exit "${2:-1}"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

while (( $# > 0 )); do
    case "$1" in
        --previous-ref)
            (( $# >= 2 )) || die '--previous-ref requires a value' 64
            PREVIOUS_REF="$2"
            shift 2
            ;;
        --output-dir)
            (( $# >= 2 )) || die '--output-dir requires a value' 64
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --full-only)
            FULL_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1" 64
            ;;
    esac
done

if [[ "$FULL_ONLY" == false && -z "$PREVIOUS_REF" ]]; then
    die 'provide --previous-ref REF or use --full-only' 64
fi

require_command git
require_command unzip
require_command sha256sum

cd "$TADK_ROOT"

[[ -f VERSION ]] || die 'VERSION is missing'
[[ -f release/manifest.json ]] || die 'release/manifest.json is missing'

if [[ -n "$(git status --porcelain)" ]]; then
    die 'the Git working tree must be clean before packaging'
fi

VERSION="$(tr -d '\r\n' < VERSION)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[a-z]+\.[0-9]+$ ]] ||
    die "invalid release version: $VERSION"

manifest_version="$(
    sed -nE 's/^[[:space:]]*"version":[[:space:]]*"([^"]+)".*/\1/p' \
        release/manifest.json | head -n 1
)"
[[ "$manifest_version" == "$VERSION" ]] ||
    die "manifest version $manifest_version does not match VERSION $VERSION"

build_from_version="${VERSION##*.}"
manifest_build="$(
    sed -nE 's/^[[:space:]]*"build":[[:space:]]*([0-9]+).*/\1/p' \
        release/manifest.json | head -n 1
)"
[[ "$manifest_build" == "$build_from_version" ]] ||
    die "manifest build $manifest_build does not match version build $build_from_version"

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tadk/releases/$VERSION"
fi
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd)"

prefix="TADK-$VERSION/"
full_archive="$OUTPUT_DIR/TADK-$VERSION.zip"
update_archive="$OUTPUT_DIR/TADK-$VERSION-update.zip"
checksum_file="$OUTPUT_DIR/TADK-$VERSION-SHA256SUMS.txt"

package_cache="${XDG_CACHE_HOME:-$HOME/.cache}/tadk/package"
mkdir -p "$package_cache"
temp_dir="$(mktemp -d "$package_cache/release.XXXXXX")"
trap 'rm -rf -- "$temp_dir"' EXIT

verify_archive() {
    local archive="$1"
    local archive_version=""
    local archive_manifest_version=""
    local invalid_entry=""

    invalid_entry="$(
        unzip -Z1 "$archive" |
            awk -v prefix="$prefix" 'index($0, prefix) != 1 { print; exit }'
    )"
    [[ -z "$invalid_entry" ]] ||
        die "archive contains an entry outside $prefix: $invalid_entry"

    archive_version="$(unzip -p "$archive" "${prefix}VERSION" | tr -d '\r\n')"
    [[ "$archive_version" == "$VERSION" ]] ||
        die "archive VERSION mismatch in $(basename "$archive")"

    archive_manifest_version="$(
        unzip -p "$archive" "${prefix}release/manifest.json" |
            sed -nE 's/^[[:space:]]*"version":[[:space:]]*"([^"]+)".*/\1/p' |
            head -n 1
    )"
    [[ "$archive_manifest_version" == "$VERSION" ]] ||
        die "archive manifest mismatch in $(basename "$archive")"
}

printf 'Building full archive for %s...\n' "$VERSION"
rm -f -- "$full_archive" "$update_archive" "$checksum_file"
git archive \
    --format=zip \
    --prefix="$prefix" \
    --output="$full_archive" \
    HEAD
verify_archive "$full_archive"

archives=("$full_archive")

if [[ "$FULL_ONLY" == false ]]; then
    previous_commit="$(git rev-parse --verify "$PREVIOUS_REF^{commit}")" ||
        die "cannot resolve previous release ref: $PREVIOUS_REF"

    git merge-base --is-ancestor "$previous_commit" HEAD ||
        die "$PREVIOUS_REF is not an ancestor of HEAD"

    mapfile -d '' -t deleted_paths < <(
        git diff --name-only -z --diff-filter=D "$previous_commit"..HEAD
    )
    if (( ${#deleted_paths[@]} > 0 )); then
        printf 'Deleted tracked files cannot be represented by the additive update contract:\n' >&2
        printf '  %s\n' "${deleted_paths[@]}" >&2
        exit 1
    fi

    mapfile -d '' -t changed_paths < <(
        git diff --name-only -z --diff-filter=ACMRT "$previous_commit"..HEAD
    )
    (( ${#changed_paths[@]} > 0 )) ||
        die "no changed tracked files since $PREVIOUS_REF"

    printf 'Building update archive from %s changed tracked files...\n' \
        "${#changed_paths[@]}"
    git archive \
        --format=zip \
        --prefix="$prefix" \
        --output="$update_archive" \
        HEAD -- "${changed_paths[@]}"
    verify_archive "$update_archive"
    archives+=("$update_archive")
fi

(
    cd "$OUTPUT_DIR"
    sha256sum "${archives[@]##*/}" > "$(basename "$checksum_file")"
)

printf '\nRelease artifacts:\n'
for archive in "${archives[@]}"; do
    printf '  %s\n' "$archive"
done
printf '  %s\n' "$checksum_file"
printf '\nChecksums:\n'
cat "$checksum_file"

rm -rf -- "$temp_dir"
trap - EXIT
