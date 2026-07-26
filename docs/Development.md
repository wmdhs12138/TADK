# Development

Keep command scripts focused on parsing and orchestration. Put reusable behavior in `lib/` and keep command contracts explicit.

Before committing, run the functional entry points that changed:

```bash
bash -n bin/tadk commands/<changed-command>.sh lib/<changed-library>.sh
bin/tadk --version
bin/tadk --help
```
