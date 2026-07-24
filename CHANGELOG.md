# Changelog

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
