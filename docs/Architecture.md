# TADK Architecture

## Command path

```text
bin/tadk
  -> command manifest and dispatcher
  -> commands/<command>.sh
  -> reusable libraries in lib/
  -> Gradle, adb and Android project tools
```

Commands such as `build`, `install`, `launch`, and `logcat` remain atomic CLI operations. Composite commands may orchestrate them through the Workflow Engine.

## Project context and configuration

Commands locate the nearest Android Gradle project from the current
directory. When `.tadk/project.conf` exists, it is parsed as data rather
than sourced as shell code. The configuration currently records:

```text
version=1
module=app
variant=debug
```

Nested modules are stored as project-relative paths such as
`feature/chat` and converted to the Gradle path `:feature:chat` for task
execution.

`tadk init` recognizes application modules declared with Kotlin or Groovy
plugin IDs, legacy `apply plugin` syntax, and Version Catalog aliases that
resolve to `com.android.application`. Commented plugin declarations and
aliases that cannot be resolved to the application plugin are ignored.

Configured module and variant values are used by `build`, `install`,
`run`, `dev`, and Release APK resolution. Explicit command-line variant
options take precedence. Projects without a configuration file retain
the legacy project-wide compatibility behavior.

## Workflow Engine

`lib/workflow.sh` is a business-agnostic sequential step runner. Its
current public API is:

```bash
workflow_register STEP FUNCTION
workflow_register_if STEP CONDITION_FUNCTION FUNCTION
workflow_before STEP FUNCTION
workflow_after STEP FUNCTION
workflow_has_step STEP
workflow_step STEP
workflow_run STEP...
```

### Workflow API compatibility contract

The seven functions above are public library APIs. Their observable
behavior is covered by `tests/unit/workflow-contract.sh` and follows these
rules:

- `workflow_register_if` returning false from its condition skips that step,
  returns success, and allows later steps to run.
- A selected step runs `condition -> before hooks -> step body -> after hooks`.
  Hooks run in registration order; an unsuccessful condition or step does not
  run the remaining hooks for that step.
- `workflow_run` is sequential and fail-fast. It returns the first non-zero
  status without running later steps.

The reserved exit codes are:

| Code | Meaning |
| ---: | --- |
| 0 | Success, including a conditionally skipped step |
| 64 | Invalid arguments or names |
| 65 | Duplicate step registration |
| 66 | Unknown step |
| 127 | Missing or unavailable function |

Consumers should depend on these public functions and codes, not on the
internal associative arrays used by the implementation.

The engine owns registration, condition checks, hook ordering, sequential
execution, fail-fast behavior, and exit-code propagation. A registered
step runs as:

```text
condition -> before hooks -> step body -> after hooks
```

The engine does not know what Android builds, APKs, adb, or logcat are.

## `dev` workflow

Beginning with `0.3.0-alpha.13-sprint.2`, `commands/dev.sh` is the first production consumer of the Workflow Engine.

```text
tadk dev
  -> parse and validate CLI options
  -> build argument arrays
  -> register Workflow steps
  -> workflow_run
       build
       install
       clear-logcat
       launch
       logcat
```

Each step delegates to an existing atomic TADK command. This preserves one implementation of build, installation, launch, and logging behavior.

Conditional behavior such as `--no-clear` and `--no-logcat` stays inside the corresponding step function. The Workflow Engine remains free of command-specific conditions.

## Failure model

The workflow is sequential. When a step returns a non-zero exit code:

1. The Workflow Engine stops immediately.
2. Later steps are not executed.
3. The failing exit code is returned to the caller.

The existing `dev` integration test verifies that a failed Gradle build prevents APK installation.

## `run` workflow

`commands/run.sh` uses the Workflow Engine while keeping its command-
specific behavior in step functions:

```text
build
  -> resolve-apk
  -> report
  -> build-only / open-installer / adb-install
  -> adb-launch
  -> logcat
  -> complete
```

Conditional steps keep their predicates in `commands/run.sh`; the engine
does not contain Android-specific conditions.

## Release workflow

`commands/release.sh` exposes Release inspection, verification, build,
keystore, setup, initialization, Gradle application, and bootstrap
operations. The underlying `lib/release_*.sh` modules own file handling,
password sourcing, marker validation, and signing behavior. Bootstrap performs
a read-only preflight for `--dry-run`; a real run snapshots its managed files
and restores them if a later step fails.

## Future extensions

Shared workflow context, plugin discovery, retries, and parallel
execution are deferred until the current command and Workflow contracts
have independent compatibility tests and a clear production use case.
