# TADK 0.3.0-alpha.16

Alpha.16 strengthens Workflow Engine failure handling and improves the
test infrastructure used to verify behavior under Bash `set -e`.

## Highlights

### Explicit Workflow failure propagation

Workflow execution now preserves the original failure status from:

- before hooks;
- the registered step function;
- after hooks;
- the first failed step in `workflow_run`.

This prevents a later successful command from overwriting the real exit
status.

The execution rules are now explicit:

- a failed before hook stops the step body;
- a failed step body skips all after hooks;
- a failed after hook stops remaining after hooks;
- `workflow_run` stops at the first failed step;
- the original nonzero status is returned to the caller.

### Errexit-safe regression coverage

Workflow failure propagation is tested inside independent Bash
processes with `set -e` enabled.

The regression coverage verifies that:

- before-hook status is preserved;
- step-body status is preserved;
- after-hook status is preserved;
- later hooks do not run after failure;
- later Workflow steps do not run after failure;
- conditional skips remain safe under `set -e`.

### Reusable process test helper

Alpha.16 adds:

    tests/helpers/process.sh

The `run_bash_errexit` helper:

- launches an independent Bash process;
- enables `set -e` inside that process;
- passes arguments without relying on outer-function positional
  parameters;
- captures the child process status in `RUN_STATUS`;
- avoids changing the caller's errexit state.

Dedicated unit tests cover:

- missing script validation;
- successful execution;
- original failure-code preservation;
- real errexit termination;
- argument forwarding;
- safe use when the caller also enables `set -e`.

### Test reliability fix

The first version of the Workflow errexit regression tests referenced
`$2` inside test functions.

Inside a Bash function, positional parameters belong to that function,
so the trace-file path became empty. Alpha.16 fixes this by capturing
the subprocess argument in a named `trace_file` variable.

## Compatibility

- No user-facing command was removed.
- No existing option was renamed.
- Conditional Workflow conditions still use nonzero status as a normal
  skip.
- Existing `tadk dev` and `tadk run` execution behavior remains
  compatible.
- TADK remains designed for Termux on ARM64 Android devices.

## Verification

Run:

    bin/tadk --version
    bin/tadk test

Expected version:

    TADK 0.3.0-alpha.16
