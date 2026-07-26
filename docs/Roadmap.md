# Roadmap

## Current baseline

- **0.3.0-alpha.20:** bilingual English/Simplified Chinese CLI resources,
  native Zsh completion generation, idempotent one-command completion
  installation, and reproducible release archive generation.
- **0.3.0-alpha.19:** functionality-first runtime, removal of test-only code,
  and production installation verification after self-update.
- **0.3.0-alpha.18:** persistent project configuration, configured
  module/variant builds, ADB device workflows, Release signing tools,
  Workflow-based run and dev.

## Next milestone

- Stabilize Alpha.20 user-facing installation and completion behavior across
  plain Zsh, Oh My Zsh, and theme-managed completion initialization.
- Keep release metadata, package archives, and checksums reproducible from a
  clean committed tree.
- Continue hardening transactional self-update recovery around interruption
  and retained recovery metadata.

## Beta target

- **0.3.0-beta.1:** stabilize public command and library contracts, document
  compatibility guarantees, complete machine-readable diagnostics, and harden
  the apply/rollback workflow against process interruption and power loss where
  recovery metadata permits.

Plugin discovery, retries, and parallel workflows remain deferred until the
current command and Workflow contracts are stable.
