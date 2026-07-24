# Architecture

TADK separates user entry points, command implementations, and reusable libraries:

- `bin/`: stable executable entry points.
- `commands/`: argument parsing and user-facing command workflows.
- `lib/`: reusable project, Gradle, APK, Android, ADB, and Logcat functions.
- `tests/`: smoke tests, fixtures, mocks, and command-level integration tests.

`bin/tadk` resolves commands through `commands/manifest`. Compatibility executables in `bin/` delegate through `lib/compat-command.sh`.
