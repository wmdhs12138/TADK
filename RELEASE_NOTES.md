# TADK 0.3.0-alpha.15

Alpha.15 completes the first production use of the TADK Workflow Engine
across both primary Android development flows: `tadk dev` and
`tadk run`.

## Highlights

### Conditional Workflow steps

The Workflow Engine now supports:

    workflow_register_if STEP CONDITION_FUNCTION FUNCTION

A conditional step:

- runs only when its condition function succeeds;
- skips its before hook, body and after hook when the condition fails;
- continues with subsequent Workflow steps after a normal skip;
- remains safe when the caller uses `set -e`;
- validates registered functions during registration and execution.

### `tadk dev` Workflow improvements

The `clear-logcat` and `logcat` stages are now registered as conditional
Workflow steps.

Existing behavior remains compatible:

- `--no-clear` skips old-log cleanup;
- `--no-logcat` skips log monitoring;
- skipped stages do not stop later Workflow steps;
- output order remains unchanged.

### `tadk run` migration

`tadk run` is now orchestrated by the Workflow Engine.

The flow consists of:

    build
    resolve-apk
    report
    build-only
    open-installer
    adb-install
    adb-launch
    complete

Installation modes remain mutually exclusive:

- default `open` mode uses `termux-open`;
- `--build-only` performs no installation;
- `--install` installs through ADB and attempts to launch the app.

No existing `tadk run` command-line option was removed or renamed.

### Explicit Gradle failure propagation

Gradle clean and build-task failures are now returned explicitly from
the build library.

This prevents later successful shell commands from accidentally
overwriting the real Gradle exit status when the caller is capturing
errors with `set +e` or another error-handling context.

### Unified testing

The Alpha.14 unified test command is included in this release:

    tadk test
    tadk test all
    tadk test unit
    tadk test smoke
    tadk test integration

Alpha.15 adds integration coverage for:

- default installer-open mode;
- release build-only mode;
- Gradle option forwarding;
- ADB install and launch order;
- build failure propagation;
- stopping the Workflow before installation after a failed build.

## Compatibility

- No user-facing command was removed.
- No existing option was renamed.
- `tadk dev` and `tadk run` preserve their previous visible operation
  order.
- TADK remains designed for Termux on ARM64 Android devices.

## Verification

Run:

    bin/tadk --version
    bin/tadk test

Expected version:

    TADK 0.3.0-alpha.15
