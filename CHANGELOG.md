# Changelog

## 0.3.0-alpha.18

### Added

- Added `tadk init` for generating `.tadk/project.conf` in an existing
  Android Gradle project.
- Added safe project configuration loading through `lib/config.sh`.
- Added module-qualified Gradle build task generation.
- Added module-scoped APK discovery and resolution.
- Added environment diagnostics through `tadk doctor`.
- Added unit and integration coverage for project initialization,
  configuration parsing, configured builds, installation and run
  workflows.

### Changed

- `tadk build` now uses the configured Android module and build variant.
- `tadk install` now resolves APKs from the configured module.
- `tadk run` now uses module-qualified Gradle tasks and module-scoped APK
  resolution.
- `tadk dev` now allows `build` and `install` to inherit the configured
  variant when no command-line variant is supplied.
- Explicit `--debug` and `--release` options continue to override the
  configured variant.
- Projects without `.tadk/project.conf` continue using the existing
  project-wide compatibility behavior.

### Fixed

- Prevented multi-module projects from building or selecting an APK from
  the wrong module when project configuration is present.
- Prevented `tadk dev` from implicitly forcing Debug builds and
  overriding `variant=release`.
- Preserved configuration state outside command-substitution
  subshells during installation.
- Added explicit failure propagation to new integration assertions.
- Kept test workspaces under `$HOME/.cache/tadk` for Termux
  compatibility.

### Configuration

A generated project configuration has this format:

    version=1
    module=app
    variant=debug

Variant precedence is:

    --debug / --release
        > project.conf variant
        > default debug

### Compatibility

- No user-facing command or option was removed.
- Existing projects do not require immediate initialization.
- Explicit APK installation remains supported.
- Existing Gradle and ADB argument forwarding remains supported.
- TADK remains designed for Termux on ARM64 Android devices.

## 0.3.0-alpha.17

### Added

- Added automatic discovery of unit test scripts under `tests/unit`.
- Added automatic discovery of integration test scripts under
  `tests/integration`.
- Added the shared `tests/helpers/suite.sh` test-suite runner.

### Changed

- Unit and integration test files are now sorted before execution for
  deterministic test order.
- Unit and integration runners now invoke discovered scripts through
  Bash instead of depending on executable permission bits.
- Simplified the unit and integration entry-point runners by moving
  shared discovery, execution and result-summary logic into
  `run_test_suite`.
- Updated release and verification documentation for Alpha.17.

### Fixed

- Registered `tests/unit/process.sh` in the unified unit suite before
  replacing the manual list with automatic discovery.
- Prevented newly added unit or integration test scripts from being
  silently omitted by fixed `TEST_FILES` arrays.
- Test suites now fail explicitly when no matching test files are
  discovered.

### Compatibility

- No user-facing command or option was removed.
- `tadk test unit`, `tadk test integration` and `tadk test` retain
  their existing output structure and exit behavior.
- Existing smoke-test behavior remains unchanged.

## 0.3.0-alpha.16

### Added

- Added reusable independent Bash process test support through
  `tests/helpers/process.sh`.
- Added dedicated unit coverage for child-process exit-code capture and
  `set -e` behavior.

### Changed

- Simplified Workflow errexit regression tests by centralizing
  independent Bash process execution.
- Updated release and verification documentation for Alpha.16.

### Fixed

- Workflow before hooks, step bodies and after hooks now propagate their
  original failure status explicitly.
- `workflow_run` now stops at the first failed step and preserves its
  original exit status.
- Fixed Workflow errexit regression tests that lost the trace-file path
  inside Bash functions.

### Compatibility

- No user-facing command or option was removed.
- Existing conditional Workflow skip semantics remain unchanged.
- Existing `tadk dev` and `tadk run` behavior remains compatible.

## 0.3.0-alpha.15

### Added

- Added `workflow_register_if STEP CONDITION_FUNCTION FUNCTION`.
- Added conditional Workflow execution that skips optional steps without
  stopping subsequent Workflow stages.
- Added integration coverage for `tadk run` open, build-only, ADB and
  failure paths.
- Added unified `tadk test` command support for unit, smoke and
  integration groups.

### Changed

- Migrated `tadk run` orchestration to the Workflow Engine.
- Migrated optional `tadk dev` logcat stages to conditional Workflow
  steps.
- Updated release and verification documentation for Alpha.15.

### Fixed

- Gradle clean and build-task failures are now propagated explicitly.
- Conditional Workflow skips remain safe under `set -e`.

### Compatibility

- No existing user-facing command or option was removed.
- Existing `tadk dev` and `tadk run` execution order remains compatible.

## 0.3.0-alpha.13-sprint.2

### Changed

- Migrated `tadk dev` orchestration to the Workflow Engine.
- `dev` now registers five symbolic steps: `build`, `install`, `clear-logcat`, `launch`, and `logcat`.
- Existing command-line options, output order, fail-fast behavior, and logcat execution remain compatible.

### Compatibility

- No user-facing command or option changes.
- `tadk run` remains on its existing implementation and is not migrated in this sprint.

## 0.3.0-alpha.13-sprint.1

### Added

- Minimal business-agnostic Workflow Engine in `lib/workflow.sh`.
- Unit test runner and Workflow Engine unit tests.
- Workflow architecture documentation.

### Changed

- Smoke verification now runs unit tests before integration tests.
