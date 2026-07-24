# Verification

Run from the TADK repository root:

```bash
bin/tadk --version
bash tests/unit/run.sh
bash tests/integration/run.sh
bash tests/smoke.sh
```

Expected version:

```text
TADK 0.3.0-alpha.13-sprint.2
```

Expected test totals:

- Workflow tests: 8 passed, 0 failed
- Unit test files: 1 passed, 0 failed
- Integration tests: 6 passed, 0 failed
- Smoke checks: 74 passed, 0 failed
