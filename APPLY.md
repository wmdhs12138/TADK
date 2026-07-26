# Install and update TADK in Termux

This is the current manual workflow for installing TADK or applying a TADK
update archive. The package rules are defined in
[`docs/Release.md`](docs/Release.md) and `release/manifest.json`.

`tadk install` installs an APK on an Android device; it does not update TADK
itself.

## Choose an archive

Use a full archive for a new installation:

```text
TADK-<version>.zip
```

Use an update archive for an existing installation:

```text
TADK-<version>-update.zip
```

The archive must contain one top-level directory named
`TADK-<version>`. Download the matching SHA-256 checksum from the same
release before continuing.

## Apply an archive

Replace the values below with the actual release, checksum, and target paths:

```bash
export TADK_VERSION="0.3.0-alpha.18"
export TADK_ROOT="$HOME/projects/TADK"
export TADK_ARCHIVE="$HOME/storage/downloads/TADK-$TADK_VERSION-update.zip"
export TADK_BACKUP="$HOME/tmp/tadk-backups/TADK-$TADK_VERSION-$(date +%Y%m%d-%H%M%S)"
export TADK_SHA256="paste-the-sha256-from-the-release-page-here"
```

Verify the checksum shown on the release page, then stage and validate the
archive without changing the target directory:

```bash
test "$(sha256sum "$TADK_ARCHIVE" | awk '{print $1}')" = "$TADK_SHA256"

if [[ -x "$TADK_ROOT/bin/tadk" ]]; then
    "$TADK_ROOT/bin/tadk" self-update --check "$TADK_ARCHIVE" \
        --sha256 "$TADK_SHA256"
fi

STAGE="$(mktemp -d "$HOME/tmp/tadk-package.XXXXXX")"
trap 'rm -rf -- "$STAGE"' EXIT
unzip -q "$TADK_ARCHIVE" -d "$STAGE"
PAYLOAD="$STAGE/TADK-$TADK_VERSION"

test -f "$PAYLOAD/VERSION"
test "$(tr -d '\r\n' < "$PAYLOAD/VERSION")" = "$TADK_VERSION"
grep -Fq '"version": "'$TADK_VERSION'"' "$PAYLOAD/release/manifest.json"
```

Back up the existing installation before copying anything. Keep this backup
outside `TADK_ROOT` so a later update cannot overwrite it:

```bash
mkdir -p "$TADK_BACKUP"
if [[ -d "$TADK_ROOT" ]]; then
    cp -a "$TADK_ROOT"/. "$TADK_BACKUP"/
fi
```

Copy the validated payload and restore executable bits if needed:

```bash
mkdir -p "$TADK_ROOT"
cp -a "$PAYLOAD"/. "$TADK_ROOT"/
chmod +x "$TADK_ROOT"/bin/* "$TADK_ROOT"/commands/*.sh
```

Finally verify the installation:

```bash
"$TADK_ROOT/bin/tadk" --version
bash "$TADK_ROOT/tests/smoke.sh"
```

If verification fails, stop using the updated tree and restore the backup
before retrying. Do not delete `.git/`, `.tadk/`, build outputs, Gradle
caches, keystores, or signing property files during an update. Update
archives only overwrite files they contain; they do not remove other files.
