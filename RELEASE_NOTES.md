# TADK 0.3.0-alpha.18

Alpha.18 introduces persistent Android project configuration and connects
it to TADK's primary development workflows.

The current `develop` line also includes ADB device workflows and Release
signing tools. This working tree adds explicit and nested module selection to
`tadk init`, plus `tadk release bootstrap --dry-run` and automatic rollback
when a later signing step fails.

## Highlights

### Initialize an existing Android project

TADK now provides:

    tadk init

The command validates the Android Gradle project and creates:

    .tadk/project.conf

The generated configuration records the selected Android application
module and default build variant:

    version=1
    module=app
    variant=debug

Existing configuration is protected from accidental replacement.
Intentional regeneration is available through:

    tadk init --force

### Safe project configuration reader

Alpha.18 adds a reusable configuration reader that:

- locates `.tadk/project.conf` relative to the project root;
- parses only supported keys;
- rejects duplicate or unknown keys;
- rejects malformed assignments;
- validates the configuration version;
- validates module and variant values;
- distinguishes an absent configuration from invalid configuration;
- avoids evaluating configuration as shell code.

The public configuration state includes:

    TADK_CONFIG_VERSION
    TADK_CONFIG_MODULE
    TADK_CONFIG_VARIANT

### Configured build workflow

`tadk build` now uses the configured module and variant.

Given:

    version=1
    module=mobile
    variant=release

TADK executes:

    :mobile:assembleRelease

The resulting APK is resolved only from:

    mobile/build/outputs/apk/release

This prevents another Android module's APK from being selected.

### Configured installation

`tadk install` now applies the same project configuration when no
explicit APK path is supplied.

The resolution precedence is:

    explicit APK path
        > configured module
        > project-wide compatibility search

Variant precedence is:

    --debug / --release
        > configured variant
        > default debug

Explicit APK installation remains supported:

    tadk install --apk ./path/to/application.apk

### Configured run workflow

`tadk run` now uses:

- module-qualified Gradle tasks;
- the configured build variant;
- module-scoped APK resolution;
- the existing Workflow Engine stages.

Existing run modes remain available:

    tadk run
    tadk run --build-only
    tadk run --install
    tadk run --open

### Development workflow inheritance

`tadk dev` remains an orchestration command. It does not duplicate
configuration parsing.

Previously, `tadk dev` always forwarded `--debug`, which overrode a
configured Release variant.

Alpha.18 changes the forwarding rule:

- without `--debug` or `--release`, no variant option is forwarded;
- `tadk build` and `tadk install` read the project configuration;
- an explicitly supplied variant is forwarded consistently to both
  commands.

For example:

    tadk dev

inherits the configured variant, while:

    tadk dev --release

explicitly selects Release.

### Environment diagnostics

Alpha.18 adds:

    tadk doctor

The command reports important Termux Android development prerequisites,
including TADK, Java, Android SDK, Gradle Wrapper and project state.

### Multi-module safety

Configured workflows reject invalid or missing modules before invoking
Gradle or ADB.

APK discovery stays within the configured module, reducing the risk of:

- building the wrong module;
- installing an APK produced by another module;
- reporting an unrelated artifact as the build result.

### Backward compatibility

Project initialization is optional.

Projects without `.tadk/project.conf` continue using the existing
project-wide behavior:

    assembleDebug
    assembleRelease

No user-facing command or option was removed.

Existing support remains for:

- explicit Debug and Release selection;
- explicit APK installation;
- Gradle argument forwarding;
- ADB argument forwarding;
- clean builds;
- cache disabling;
- task reruns;
- build-only, open-installer and ADB installation run modes.

## Verification

Run from the TADK repository root:

    git diff --check
    bash -n commands/init.sh
    bash -n commands/build.sh
    bash -n commands/install.sh
    bash -n commands/run.sh
    bash -n commands/dev.sh
    bin/tadk --version
    bin/tadk test unit
    bin/tadk test smoke
    bin/tadk test integration
    bin/tadk test

Expected version:

    TADK 0.3.0-alpha.18

The complete test suite should finish with no failed test groups.

## Platform

TADK remains designed for Termux on ARM64 Android devices.

This is an alpha prerelease intended for development and testing.
