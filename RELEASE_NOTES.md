# TADK 0.3.0-alpha.20

Alpha.20 improves the day-to-day command-line experience in Termux with
bilingual output and reliable native Zsh completion.

## Highlights

### English and Simplified Chinese CLI

TADK now loads English or Simplified Chinese command resources according to
`TADK_LANG` or the active shell locale:

    TADK_LANG=en tadk --help
    TADK_LANG=zh-CN tadk --help

When no supported locale is available, TADK keeps the existing Simplified
Chinese fallback.

### Native Zsh completion

Generate a completion script without modifying the system:

    tadk completion zsh

The generated completion covers top-level commands, `release` and `config`
actions, common options, APK and archive paths, keystores, Logcat formats, and
authorized ADB device serials.

### One-command completion installation

Install completion and configure Zsh with:

    tadk completion install zsh
    exec zsh

The installer:

- installs `_tadk` in the Termux Zsh `site-functions` directory;
- writes one marked and managed block to `.zshrc`;
- creates a timestamped backup before changing an existing configuration;
- can be run repeatedly without duplicating configuration;
- migrates the earlier manual TADK completion snippet;
- explicitly binds `_tadk` when completion was initialized earlier by a theme
  or shell framework.

### Reproducible release archives

`scripts/package-release.sh` creates the package-contract archives and their
SHA-256 checksum file from committed Git content. The update archive is built
from tracked files changed since an explicit previous release ref.

## Existing functionality

Alpha.20 preserves the existing project configuration, module-scoped build and
APK resolution, ADB device workflows, Release signing tools, Workflow-based
run/dev orchestration, machine-readable diagnostics, and transactional
self-update apply behavior.

## Verification

Run from the repository root:

    find bin commands lib scripts -type f -name '*.sh' -exec bash -n {} +
    bash -n bin/tadk
    bash -n bin/newapp
    git diff --check
    bin/tadk --version
    TADK_LANG=en bin/tadk --help
    TADK_LANG=zh-CN bin/tadk --help
    bin/tadk completion --help
    bin/tadk completion zsh > /tmp/_tadk
    zsh -n /tmp/_tadk

Expected version:

    TADK 0.3.0-alpha.20

## Platform

TADK remains designed for Termux on ARM64 Android devices. This is an alpha
prerelease intended for development and deployment.
