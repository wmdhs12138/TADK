# Functional verification

Run all commands from the TADK repository root.

## Version

    bin/tadk --version

Expected:

    TADK 0.3.0-alpha.19

## Static checks

    find bin commands lib \
        -type f -name '*.sh' \
        -exec bash -n {} +

    git diff --check

## Command entry points

Verify the command registry and the primary CLI entry points:

    bin/tadk --help
    bin/tadk --version
    bin/tadk info --help
    bin/tadk build --help
    bin/tadk run --help
    bin/tadk dev --help
    bin/tadk self-update --help

## Release consistency

The release metadata must remain aligned:

- `VERSION` contains the release version;
- `bin/tadk --version` matches `VERSION`;
- `release/manifest.json` matches `VERSION`.
