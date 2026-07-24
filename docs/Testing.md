# Testing

TADK uses two layers:

1. `tests/smoke.sh` validates shell syntax, the command manifest, help entry points, and library symbols.
2. `tests/integration/run.sh` runs commands against an isolated Android fixture with mock `adb` and `gradlew` executables.

Each integration test creates a temporary workspace and restores the original `PATH` during cleanup. Real devices, SDK downloads, and Gradle dependencies are not required.
