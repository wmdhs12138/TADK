# Changelog

## 0.3.0-alpha.12 — 2026-07-24

### Added
- Integration coverage for `build`, `logcat`, and `dev`.
- Assertions for ordering and absent files.
- Mock controls for Gradle failures and Android application state.

### Changed
- Integration runner now executes six command suites.
- Mock environment restores `PATH` during cleanup.
- Mock installation records the fixture package for end-to-end `dev` testing.

### Fixed
- Deterministic cleanup of temporary test environments.
- Failure-path validation preventing later workflow steps after a build error.
