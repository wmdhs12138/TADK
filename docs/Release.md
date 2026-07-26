# Release

A release must have a clean version identifier, updated release notes, and
working command entry points. `VERSION` and
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

The current supported workflow is transactional apply and is documented in
[APPLY.md](../APPLY.md). It is intentionally separate from tadk install,
which installs an APK onto an Android device.

1. Download the full or update archive and its published SHA-256 checksum.
2. Confirm the archive name, checksum, and top-level directory.
3. For an existing installation, run
   tadk self-update --apply ARCHIVE --sha256 HASH, optionally supplying
   --backup-dir DIR. For a new installation, extract into a temporary
   directory and confirm VERSION plus the release manifest before touching
   the target TADK directory.
4. The apply command reuses the read-only preflight, rejects a symlink root,
   dirty Git worktree, unsafe backup path, and concurrent transaction, then
   creates a complete backup outside the target.
5. The payload is copied additively/overwrite-only. The target directory is
   never deleted during normal apply, and protected local state is not in the
   archive payload.
6. The command verifies VERSION and the installed command manifest after copying.
7. Any copy or verification failure automatically restores the target from
   the complete backup. The backup is retained for diagnostics.

All self-update extraction, lock, and temporary state is stored under
$HOME/.cache/tadk/self-update; the implementation does not use /tmp.
There is no explicit rollback command in this PR. SIGKILL and sudden power
loss recovery remain outside the transaction boundary and require manual
recovery from the retained backup.
