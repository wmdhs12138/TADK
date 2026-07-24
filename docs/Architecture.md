# Architecture

TADK separates stable entry points, command implementations, reusable libraries,
and tests:

- `bin/`: stable executable entry points.
- `commands/`: argument parsing and user-facing command workflows.
- `lib/`: reusable project, Gradle, APK, Android, ADB, Logcat, and workflow functions.
- `tests/`: smoke tests, unit tests, fixtures, mocks, and command-level integration tests.

`bin/tadk` resolves commands through `commands/manifest`. Compatibility
executables in `bin/` delegate through `lib/compat-command.sh`.

## Workflow Engine

`lib/workflow.sh` is a small, business-agnostic sequential execution engine. It
maps symbolic step names to shell functions and runs those steps in order.

Its public API is intentionally limited to:

```bash
workflow_register STEP FUNCTION
workflow_has_step STEP
workflow_step STEP
workflow_run STEP...
```

The engine does not know what `build`, `install`, `launch`, or any future step
means. Command modules or plugins own those implementations and register them.
A failing step stops the workflow immediately, and its exit status is returned
to the caller.

Alpha.13 Sprint 1 introduces and tests the engine without migrating existing
commands. Command migration happens only after the engine passes independent
unit tests.
