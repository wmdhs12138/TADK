# Roadmap

## Current baseline

- **0.3.0-alpha.18:** persistent project configuration, configured
  module/variant builds, ADB device workflows, Release signing tools,
  Workflow-based `run` and `dev`, and the unified test command.
- Working-tree hardening: explicit and nested Android module selection in
  `tadk init`, plus dry-run and rollback protection for Release bootstrap.

## Next milestone

- **0.3.0-alpha.19:** stabilization before more feature expansion.
  CI verification, the initial Workflow API compatibility contract, and
  improved module-plugin detection are complete. Machine-readable doctor and
  device diagnostics are now available. Release toolchain diagnostics are
  now available as well. The next priority is the installation/update
  workflow. The package naming, archive layout, checksum, preservation, and
  manual rollback contract are now defined in `release/manifest.json`,
  `docs/Release.md`, and `APPLY.md`.

## Beta target

- **0.3.0-beta.1:** stabilize public command and library contracts,
  document compatibility guarantees, complete machine-readable diagnostics,
  and implement a tested installation/update workflow on top of the package
  contract.

Plugin discovery, retries, and parallel workflows remain deferred until
the current command and Workflow contracts are stable.
