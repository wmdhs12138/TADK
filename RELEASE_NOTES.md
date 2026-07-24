# TADK 0.3.0-alpha.12

This release completes the first command-level integration test baseline. It does not change production command behavior.

Validated workflows:

- Debug and release builds, clean builds, Gradle argument forwarding, and Gradle failure propagation.
- Package-filtered, all-device, raw, line-limited, and clear-only Logcat flows.
- Full `dev` orchestration order plus no-clear, no-restart, no-logcat, and early-failure behavior.
