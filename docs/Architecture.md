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

## Workflow Engine

`lib/workflow.sh` is a business-agnostic sequential step runner. Its public MVP API is:

```bash
workflow_register STEP FUNCTION
workflow_has_step STEP
workflow_step STEP
workflow_run STEP...
```

The engine owns registration, lookup, ordered execution, fail-fast behavior, and exit-code propagation. It does not know what Android builds, APKs, adb, or logcat are.

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

## Current migration boundary

`tadk run` is intentionally not migrated yet. It includes specialized build-only, APK reporting, timing, Termux opening, install, and launch behavior. It should only move to the Workflow Engine after those semantics can be preserved without forcing business logic into the engine.

## Future extensions

Hooks, shared workflow context, plugins, retries, conditional pipelines, and parallel execution are outside the MVP. They should be introduced only with independent tests and a clear production use case.
