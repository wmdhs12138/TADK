# Roadmap

## Current baseline

- **0.3.0-alpha.18:** persistent project configuration, configured
  module/variant builds, ADB device workflows, Release signing tools,
  Workflow-based run and dev, and the unified test command.
- Working-tree hardening: explicit and nested Android module selection in
  tadk init, plus dry-run and rollback protection for Release bootstrap.

## Next milestone

- **0.3.0-alpha.19:** stabilization before more feature expansion.
  CI verification, the initial Workflow API compatibility contract, and
  improved module-plugin detection are complete. Machine-readable doctor and
  device diagnostics are now available. Release toolchain diagnostics are
  now available as well. The package naming, archive layout, checksum,
  preservation, and manual rollback contract are defined in
  release/manifest.json, docs/Release.md, and APPLY.md. The read-only
  tadk self-update --check preflight is available. Transactional
  tadk self-update --apply is now available with complete backup,
  additive/overwrite-only copy, post-apply smoke verification, and automatic
  rollback.

## Beta target

- **0.3.0-beta.1:** stabilize public command and library contracts,
  document compatibility guarantees, complete machine-readable diagnostics,
  and harden the tested apply/rollback workflow against process interruption
  and power loss where recovery metadata permits.

Plugin discovery, retries, and parallel workflows remain deferred until
the current command and Workflow contracts are stable.
