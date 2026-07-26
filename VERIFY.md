# Functional verification

Run all commands from the TADK repository root.

## Version

    bin/tadk --version

Expected:

    TADK 0.3.0-alpha.20

## Static checks

    find bin commands lib scripts \
        -type f -name '*.sh' \
        -exec bash -n {} +

    bash -n bin/tadk
    bash -n bin/newapp

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
    TADK_LANG=en bin/tadk --help
    TADK_LANG=zh-CN bin/tadk --help
    bin/tadk completion --help
    bin/tadk completion zsh > /tmp/_tadk
    zsh -n /tmp/_tadk

## Release consistency

The release metadata must remain aligned:

- `VERSION` contains the release version;
- `bin/tadk --version` matches `VERSION`;
- `release/manifest.json` matches `VERSION`.
