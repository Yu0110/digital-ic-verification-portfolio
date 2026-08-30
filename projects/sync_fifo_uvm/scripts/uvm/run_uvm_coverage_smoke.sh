#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UVM_TESTNAME=fifo_uvm_coverage_test \
EXPECTED_UVM_MARKER="UVM COVERAGE PASS" \
COVERAGE_FILE=/tmp/fifo_uvm_directed_coverage.dat \
"${SCRIPT_DIR}/run_uvm_smoke.sh"
