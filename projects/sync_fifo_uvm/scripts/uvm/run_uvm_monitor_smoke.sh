#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UVM_TESTNAME=fifo_uvm_monitor_test \
EXPECTED_UVM_MARKER="UVM MONITOR PASS" \
"${SCRIPT_DIR}/run_uvm_smoke.sh"
