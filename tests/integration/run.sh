#!/usr/bin/env bash
set -Eeuo pipefail

TADK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
INTEGRATION_DIR="$TADK_ROOT/tests/integration"
RUNNER_PATH="$INTEGRATION_DIR/run.sh"

source "$TADK_ROOT/tests/helpers/suite.sh"

run_test_suite integration "$INTEGRATION_DIR" "$RUNNER_PATH"
