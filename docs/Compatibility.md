# Compatibility Policy

TADK separates stable public contracts from implementation details.

## Stable contracts

- Public `bin/tadk` commands and their documented options.
- The `.tadk/project.conf` format. `version=1` remains readable throughout
  the 0.3.x line.
- The Workflow API listed in `docs/Architecture.md`, including its exit codes,
  ordering, and fail-fast behavior.
- Existing projects without `.tadk/project.conf`, which retain legacy
  project-wide build and APK resolution behavior.

## Change policy

- New commands, options, and fields are additive when practical.
- Existing options keep their meaning within a minor release.
- A breaking change requires a migration note, a versioned compatibility
  decision, and tests covering the new behavior.
- Internal library helpers and associative-array layouts are not public API.

## Verification

Public contracts must have either unit tests for library behavior or
integration tests for observable command behavior. GitHub Actions runs the
complete unit, smoke, and integration suites for pull requests targeting
`develop` and `main`.
