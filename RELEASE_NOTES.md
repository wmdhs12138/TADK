# TADK 0.3.0-alpha.13 Sprint 2

This sprint puts the Workflow Engine into real use by migrating `tadk dev`.

The visible development loop remains:

1. Build APK
2. Install APK
3. Clear old logcat output when enabled
4. Launch the application
5. Follow or dump application logs

Internally, these operations are now registered and executed as Workflow steps. A failed step stops the remaining workflow with the same exit code.

`tadk run` is intentionally unchanged because it still contains specialized behavior that does not map cleanly to the current Workflow MVP.
