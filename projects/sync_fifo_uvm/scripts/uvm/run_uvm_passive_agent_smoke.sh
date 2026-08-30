#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UVM_TESTNAME=fifo_uvm_passive_agent_test \
EXPECTED_UVM_MARKER="UVM PASSIVE AGENT PASS" \
"${SCRIPT_DIR}/run_uvm_smoke.sh"
