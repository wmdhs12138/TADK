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

## Usage

```bash
tadk newapp MyApp com.example.myapp
```

## Project status

Current development version: '0.3.0-alpha.12'


## Environment diagnostics

Check whether Java, Android SDK, ARM64 build tools and TADK are
configured correctly:

```bash
tadk doctor
```

## Build and run an application

Run this command from an Android project or any of its subdirectories:

```bash
tadk run
```

### Useful options:

```bash
tadk run --build-only
tadk run --clean
tadk run --install
tadk run --release --build-only
```

By default, TADK builds a Debug APK and opens the Android package installer using termux-open.

## Clean project build files

Remove build outputs from the current Android project:

```bash
tadk clean
```

### Inspect project cache usage without deleting anything:

```bash
tadk clean --status
```

### Preview a cleanup:

```bash
tadk clean --dry-run
```

### Remove build outputs and the project-local Gradle cache:

```bash
tadk clean --deep
```

TADK does not remove the global Gradle dependency cache under ~/.gradle/caches.

## Internal architecture

TADK commands share reusable shell libraries:

```text
lib/common.sh   Common output, command and size helpers
lib/project.sh  Android Gradle project discovery
lib/apk.sh      APK artifact discovery
```

Commands should reuse these libraries instead of implementing duplicate project detection and output helpers.
