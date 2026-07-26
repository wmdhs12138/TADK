# Install and update TADK in Termux

This is the supported workflow for installing TADK or applying a TADK update
archive. The package rules are defined in
[docs/Release.md](docs/Release.md) and release/manifest.json.

tadk install installs an APK on an Android device; it does not update TADK
itself.

## Choose an archive

Use a full archive for a new installation:

~~~text
TADK-<version>.zip
~~~

Use an update archive for an existing installation:

~~~text
TADK-<version>-update.zip
~~~

The archive must contain one top-level directory named TADK-<version>.
Obtain the matching SHA-256 checksum from the same release before continuing.

## Apply an archive

Replace the values below with the actual archive, checksum, and optional
backup path. The command always updates the TADK installation that contains
the invoked bin/tadk; it has no arbitrary target-directory option.

~~~bash
export TADK_ARCHIVE="$HOME/storage/downloads/TADK-<version>-update.zip"
export TADK_SHA256="paste-the-sha256-from-the-release-page-here"
export TADK_BACKUP="$HOME/backups/tadk-$(date +%Y%m%d-%H%M%S)"
~~~

--apply requires exactly 64 hexadecimal SHA-256 characters. It reuses the
read-only preflight and does not create the backup or modify the installation
until every hard preflight check has passed:

~~~bash
"$HOME/projects/TADK/bin/tadk" self-update \
    --apply "$TADK_ARCHIVE" \
    --sha256 "$TADK_SHA256" \
    --backup-dir "$TADK_BACKUP"
~~~

If --backup-dir is omitted, the complete backup is retained under
$HOME/.cache/tadk/self-update/backups/. A supplied backup directory must be
new or empty, must be outside the current TADK root, and is retained after
the command completes. The transaction also uses
$HOME/.cache/tadk/self-update/ for extraction, locking, and other temporary
state; it does not use /tmp.

The apply state machine is:

1. Run the existing archive preflight, then acquire the exclusive update lock.
2. Reject a symlink TADK root, a dirty Git worktree, an unsafe backup path, or
   a concurrent update.
3. Create a complete backup outside the target, including .git, .tadk, build
   caches, keystores, and signing configuration.
4. Additively/overwriting-copy the validated payload without deleting the
   target directory.
5. Verify VERSION and the installed command manifest.
6. On any copy or verification failure, remove the target's children and
   restore them from the complete backup. The target directory itself is
   preserved.

Use --json for one versioned machine-readable result. It reports the
preflight, lock, backup, copy, post-apply verification, and rollback checks.
There is intentionally no explicit rollback command in this release; a
failed transaction rolls back automatically. A process killed with SIGKILL
or by sudden power loss can still leave a partially copied target and retained
lock/backup state for manual recovery.
