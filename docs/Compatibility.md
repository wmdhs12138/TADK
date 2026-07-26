# Compatibility Policy

TADK separates stable public contracts from implementation details.

## Stable contracts

- Public bin/tadk commands and their documented options.
- The .tadk/project.conf format. version=1 remains readable throughout
  the 0.3.x line.
- The Workflow API listed in docs/Architecture.md, including its exit codes,
  ordering, and fail-fast behavior.
- Existing projects without .tadk/project.conf, which retain legacy
  project-wide build and APK resolution behavior.

## Machine-readable diagnostics

tadk doctor --json PROJECT_ROOT emits one JSON object and keeps the same exit
status rules as text mode.

- version is the diagnostics schema version and is currently 1.
- status is pass, warn, or fail.
- checks is ordered; each item contains a status and a human-readable
  message.
- exit_code is 0 when no hard check fails and 1 otherwise.
- Text output remains the default and is unchanged.

tadk devices --json uses the same schema version and returns a stable device
array. Each device includes serial, state, details, manufacturer/model,
Android and SDK versions, foreground package, connection_type, and
wireless_address. The summary exposes total and available counts.

tadk release doctor --json reports the Release signing toolchain with the same
version, status, exit_code, summary, and ordered checks shape. Each check
contains a name, status, and human-readable detail.

tadk self-update --check ARCHIVE --json validates a TADK package without
modifying the current installation. It uses schema version 1 and returns
archive metadata plus ordered checks for the archive name, checksum, layout,
version, package contract, and preserved paths. --sha256 HASH adds the
expected checksum; omitting it produces a warn result rather than claiming
cryptographic verification.

tadk self-update --apply ARCHIVE --sha256 HASH --json uses the same version 1
object and ordered checks. Apply requires exactly 64 hexadecimal SHA-256
characters, updates only the current TADK_ROOT, and reports lock, backup,
copy, post-apply VERSION/installation verification, and automatic rollback
checks.
Its process exit code remains 0 only for a committed transaction; hard
preflight, copy, or verification failures return 1. Existing --check text and
JSON output remain compatible.

## Change policy

- New commands, options, and fields are additive when practical.
- Existing options keep their meaning within a minor release.
- A breaking change requires a migration note and a versioned compatibility
  decision.
- Internal library helpers and associative-array layouts are not public API.

## Verification

Public contracts are verified through the command manifest, explicit exit
codes, and the functional CLI entry points documented for each command.
