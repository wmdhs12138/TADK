# Verification

Run from the TADK repository root:

```bash
bash -n lib/workflow.sh
bash -n tests/unit/workflow.sh
bash -n tests/unit/run.sh
bash tests/unit/run.sh
bash tests/smoke.sh
```

Expected result:

- 8 Workflow Engine cases pass.
- Unit test runner passes.
- Existing smoke and integration suites continue to pass.
