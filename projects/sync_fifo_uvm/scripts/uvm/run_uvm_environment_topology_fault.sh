#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UVM_TESTNAME=fifo_uvm_environment_topology_fault_test \
EXPECTED_UVM_FATALS=1 \
EXPECTED_HARNESS_COMPLETION=0 \
EXPECTED_UVM_MARKER="environment expected at least scoreboard and coverage subscribers, got 1" \
"${SCRIPT_DIR}/run_uvm_smoke.sh"
