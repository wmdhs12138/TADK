# Termux Android DevKit

[English](README.md) | [简体中文](README.zh-CN.md)

TADK is a Termux-first Android development toolkit for creating,
building and maintaining modern Android applications directly
on ARM64 Android devices.

## Current features

- Create Kotlin and Jetpack Compose projects
- Material 3 project template
- Android SDK 36 support
- Gradle Wrapper support
- Termux-native AAPT2 compatibility
- Automatic Git repository initialization
- APK discovery, installation and application launch commands
- Package-filtered logcat support
- Composed `tadk dev` development workflow
- Workflow-based `tadk run` orchestration
- ADB device inspection, wireless pairing and target-device selection
- Release APK verification and signing setup workflows
- Existing-project initialization with `.tadk/project.conf`
- Configured module and variant support across build/install/run/dev
- Environment diagnostics through `tadk doctor`

## Project status

Current development version: `0.3.0-alpha.19`

Alpha.18 adds persistent Android project configuration. TADK can now
initialize existing projects and consistently apply the configured
module and variant across build, install, run and development workflows.

The development branch also includes ADB device workflows and the
Release signing toolchain used to inspect, configure and verify Release
APKs. The current hardening work adds explicit/nested module selection and
recoverable Release bootstrap setup.

This is an alpha release intended for development and deployment in
Termux on ARM64 Android devices.

## Language support

TADK supports English and Simplified Chinese command-line output. Set
`TADK_LANG` for a command or export it for the current shell:

    TADK_LANG=en tadk --help
    TADK_LANG=zh-CN tadk --help

Language resources are stored in [`language/`](language/). When `TADK_LANG`
is not set, TADK follows the shell locale and falls back to Simplified Chinese.

## Install and update TADK

TADK currently uses a verified manual archive workflow. Use a full archive for
a new installation and an update archive for an existing installation. Follow
[`APPLY.md`](APPLY.md) for checksum verification, staging, backup, and
installation integrity steps.

Before applying an update to an existing installation, run the read-only
preflight:

    tadk self-update --check TADK-<version>-update.zip --sha256 <sha256>

The `tadk install` command is for installing APKs on Android devices; it does
not update the TADK toolkit itself.

## Usage

Create a project:

    tadk newapp MyApp com.example.myapp

## Initialize an existing project

Run this from an existing Android Gradle project:

    tadk init
    tadk init --module feature/chat

TADK creates:

    .tadk/project.conf

Example:

    version=1
    module=app
    variant=debug

Nested Android modules use a project-relative path such as
`feature/chat`. TADK converts it to the corresponding Gradle project
path when building.

The configured module and variant are applied by:

    tadk build
    tadk install
    tadk run
    tadk dev

Command-line `--debug` and `--release` options take precedence over the
configured variant.

## Environment diagnostics

Check whether Java, Android SDK, ARM64 build tools and TADK are
configured correctly:

    tadk doctor

For scripts and CI, request a stable JSON result:

    tadk doctor --json

## Devices and Release signing

Inspect connected Android devices and their current state:

    tadk devices

For scripts and CI, request a stable JSON inventory:

    tadk devices --json

Pair, connect or disconnect Android wireless debugging devices:

    tadk connect --pair HOST:PAIR_PORT
    tadk connect HOST:CONNECT_PORT

Inspect the Release environment and verify a Release APK:

    tadk release doctor
    tadk release doctor --json
    tadk release verify
    tadk release build

The complete signing setup workflow is available through
`tadk release bootstrap`. Passwords are supplied through environment
variables and are not written into command arguments. Use
`tadk release bootstrap --dry-run` to inspect the targets first; a real
bootstrap uses a temporary transaction snapshot and rolls managed files back
if a later step fails.

## Build and run an application

Run this command from an Android project or any of its subdirectories:

    tadk run

Useful options:

    tadk run --build-only
    tadk run --clean
    tadk run --install
    tadk run --release --build-only

When `.tadk/project.conf` exists, TADK uses its configured module and
variant. Without configuration, TADK retains the existing Debug and
project-wide compatibility behavior.

The `--debug` and `--release` options override the configured variant.
By default, `tadk run` opens the Android package installer using
`termux-open`.

Internally, `tadk run` uses the Workflow Engine for these stages:

    build
    resolve-apk
    report
    build-only / open-installer / adb-install
    adb-launch
    complete

## Development workflow

Build, install, launch and inspect logs in one command:

    tadk dev

Conditional stages such as clearing old logs and following logcat are
implemented as Workflow Engine steps.

## Clean project build files

Remove build outputs from the current Android project:

    tadk clean

Inspect project cache usage without deleting anything:

    tadk clean --status

Preview a cleanup:

    tadk clean --dry-run

Remove build outputs and the project-local Gradle cache:

    tadk clean --deep

TADK does not remove the global Gradle dependency cache under
`~/.gradle/caches`.

## Internal architecture

TADK commands share reusable shell libraries:

    lib/common.sh    Common output, command and size helpers
    lib/project.sh   Android Gradle project discovery
    lib/module.sh    Android module path validation and Gradle path mapping
    lib/apk.sh       APK artifact discovery
    lib/build.sh     Gradle build execution
    lib/adb.sh       ADB operations
    lib/android.sh   Android project metadata
    lib/workflow.sh  Reusable workflow orchestration

Commands should reuse these libraries instead of implementing duplicate
project detection, build, APK, ADB or output logic.
