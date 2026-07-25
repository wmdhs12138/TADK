#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
UNIT_DIR="$TADK_ROOT/tests/unit"
RUNNER_PATH="$UNIT_DIR/run.sh"

source "$TADK_ROOT/tests/helpers/suite.sh"

run_test_suite unit "$UNIT_DIR" "$RUNNER_PATH"
