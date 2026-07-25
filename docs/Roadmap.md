# Roadmap

## Current baseline

- **0.3.0-alpha.18:** persistent project configuration, configured
  module/variant builds, ADB device workflows, Release signing tools,
  Workflow-based `run` and `dev`, and the unified test command.
- Working-tree hardening: explicit and nested Android module selection in
  `tadk init`, plus dry-run and rollback protection for Release bootstrap.

## Next milestone

- **0.3.0-alpha.19:** stabilization before more feature expansion.
  CI verification and the initial Workflow API compatibility contract are
  complete. The next priorities are improved module-plugin detection and
  broader command diagnostics.

## Beta target

- **0.3.0-beta.1:** stabilize public command and library contracts,
  document compatibility guarantees, add machine-readable diagnostics,
  and define the installation/update workflow.

Plugin discovery, retries, and parallel workflows remain deferred until
the current command and Workflow contracts are stable.
