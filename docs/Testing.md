# Testing

TADK uses two layers:

1. `tests/smoke.sh` validates shell syntax, the command manifest, help entry points, and library symbols.
2. `tests/integration/run.sh` runs commands against an isolated Android fixture with mock `adb` and `gradlew` executables.

Each integration test creates a temporary workspace and restores the original `PATH` during cleanup. Real devices, SDK downloads, and Gradle dependencies are not required.

## GitHub Actions

The `Tests` workflow runs on pull requests targeting `develop` or `main`, and on
pushes to those branches. It executes the same public test entry points used by
contributors:

```text
bash bin/tadk test unit
bash bin/tadk test smoke
bash bin/tadk test integration
```

The workflow requires only the Ubuntu runner's Bash environment; Android
devices, SDK downloads, and Gradle dependencies are not required.

## Contract tests

`tests/unit/workflow-contract.sh` locks the public Workflow API surface,
reserved exit codes, hook ordering, conditional skipping, and fail-fast
behavior. Changes to `lib/workflow.sh` should update this contract only when
the compatibility policy changes deliberately.
