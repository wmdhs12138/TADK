# Changelog

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
