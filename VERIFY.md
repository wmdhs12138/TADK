# Verification

Run all commands from the TADK repository root.

## Version

    bin/tadk --version

Expected:

    TADK 0.3.0-alpha.18

## Static checks

    find bin commands lib tests \
        -type f -name '*.sh' \
        -exec bash -n {} +

    git diff --check

## Test suite

Run the complete suite:

    bin/tadk test

Run individual groups when diagnosing a failure:

    bin/tadk test unit
    bin/tadk test smoke
    bin/tadk test integration

All groups must finish with zero failed tests.

Exact test totals are intentionally not recorded here because they
change whenever coverage is expanded.

## Release consistency

The unit suite verifies that:

- `VERSION` contains a valid TADK version;
- `bin/tadk --version` matches `VERSION`;
- README, release notes, changelog and verification documentation
  reference the current version.
