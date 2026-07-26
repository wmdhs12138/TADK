# Release

A release must have a clean version identifier, updated release notes, passing
smoke tests, and passing integration tests. `VERSION` and
`release/manifest.json` are the source of truth for the release version and
package contract.

## Package contract

The current contract is version 1 in `release/manifest.json`. Replace
`{version}` below with the value from `VERSION`:

| Package | Name | Contents |
| --- | --- | --- |
| Full | `TADK-{version}.zip` | All tracked TADK files |
| Update | `TADK-{version}-update.zip` | Only tracked files changed since the previous release |

Both archives must contain one top-level directory named
`TADK-{version}`. The archive payload must not include `.git/`, project-local
`.tadk/` state, build outputs, Gradle caches, keystores, or signing property
files. An update copies changed tracked files over an existing TADK tree; it
does not delete files that are absent from the update archive.

Every published archive must have a SHA-256 checksum. The checksum is checked
before extraction and the extracted `VERSION` and
`release/manifest.json` must both match the requested release.

## Installation and update workflow

The current supported workflow is manual and is documented in
[`APPLY.md`](../APPLY.md). It is intentionally separate from `tadk install`,
which installs an APK onto an Android device.

1. Download the full or update archive and its published SHA-256 checksum.
2. Confirm the archive name, checksum, and top-level directory.
3. For an existing installation, run the read-only
   `tadk self-update --check ARCHIVE --sha256 HASH` preflight. For a new
   installation, extract into a temporary directory and confirm `VERSION`
   plus the release manifest before touching the target TADK directory.
4. Make a backup outside the target directory. The backup must include local
   `.tadk/` state, repository metadata, build outputs, and signing material.
5. Copy the archive payload into the target. Never remove the target first;
   update archives are additive/overwrite-only.
6. Restore executable bits where the extraction tool did not preserve them,
   then run `bin/tadk --version` and `bash tests/smoke.sh`.
7. Keep the backup until both checks pass. If either check fails, stop using
   the target and restore the backup before retrying.

The read-only preflight is intentionally separate from applying an update. The
next implementation slice can add an explicit apply mode only after archive
verification, preserved paths, and rollback behavior are tested independently.
