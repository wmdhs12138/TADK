# TADK 0.3.0-alpha.17

Alpha.17 improves the reliability and maintainability of TADK's test
infrastructure. Unit and integration suites now discover test scripts
automatically and share one common suite runner.

## Highlights

### Automatic unit test discovery

The unit runner now discovers all shell test files directly under:

    tests/unit

The runner:

- finds every `*.sh` file;
- excludes its own `run.sh` entry point;
- sorts test files for deterministic execution;
- runs each test through Bash;
- fails explicitly if no unit tests are found.

This prevents a newly added test file from being silently omitted from
`tadk test unit`.

### Process helper suite registration

Before automatic discovery was introduced,
`tests/unit/process.sh` existed but was missing from the fixed unit
test list.

Alpha.17 first registers that suite explicitly, ensuring the reusable
errexit process helper is covered by the unified test command.

### Automatic integration test discovery

The integration runner now applies the same discovery rules under:

    tests/integration

New integration test scripts are automatically included in both:

    tadk test integration
    tadk test

The integration suite no longer depends on a manually maintained
`TEST_FILES` array.

### Shared test-suite runner

Alpha.17 adds:

    tests/helpers/suite.sh

The shared `run_test_suite` function centralizes:

- argument validation;
- suite-directory validation;
- test-file discovery;
- runner exclusion;
- deterministic sorting;
- per-file execution;
- pass and failure counting;
- empty-suite failure;
- final suite status reporting.

The unit and integration `run.sh` files are now thin entry points that
only define their suite directory and call the shared helper.

### Stable execution behavior

Discovered test files are invoked using:

    bash "$test_file"

This means suite execution does not depend on the executable bit of
individual test scripts.

The runner continues executing all discovered files, reports every
failure, and returns a nonzero status when at least one test fails.

## Compatibility

- No user-facing command was removed.
- No existing option was renamed.
- `tadk test unit` remains supported.
- `tadk test integration` remains supported.
- The complete `tadk test` command remains supported.
- Existing output headings and pass/failure summaries remain
  compatible.
- Smoke-test behavior is unchanged.
- TADK remains designed for Termux on ARM64 Android devices.

## Verification

Run:

    bin/tadk --version
    bin/tadk test unit
    bin/tadk test integration
    bin/tadk test

Expected version:

    TADK 0.3.0-alpha.17
