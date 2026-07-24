# Termux Android DevKit

TADK is a Termux-first Android development toolkit for creating,
building, testing and maintaining modern Android applications directly
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
- Unified unit, smoke and integration test command

## Project status

Current development version: `0.3.0-alpha.15`

This is an alpha release intended for development and testing in
Termux on ARM64 Android devices.

## Usage

Create a project:

    tadk newapp MyApp com.example.myapp

Run the complete test suite:

    tadk test

Run one test group:

    tadk test unit
    tadk test smoke
    tadk test integration

## Environment diagnostics

Check whether Java, Android SDK, ARM64 build tools and TADK are
configured correctly:

    tadk doctor

## Build and run an application

Run this command from an Android project or any of its subdirectories:

    tadk run

Useful options:

    tadk run --build-only
    tadk run --clean
    tadk run --install
    tadk run --release --build-only

By default, TADK builds a Debug APK and opens the Android package
installer using `termux-open`.

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
    lib/apk.sh       APK artifact discovery
    lib/build.sh     Gradle build execution
    lib/adb.sh       ADB operations
    lib/android.sh   Android project metadata
    lib/workflow.sh  Reusable workflow orchestration
    lib/test.sh      Unified test runner

Commands should reuse these libraries instead of implementing duplicate
project detection, build, APK, ADB or output logic.
