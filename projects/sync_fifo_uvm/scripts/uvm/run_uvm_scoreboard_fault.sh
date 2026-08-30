#!/usr/bin/env bash

set -euo pipefail

# 运行记分板预期负向测试，六类字段篡改都必须被识别。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UVM_TESTNAME=fifo_uvm_scoreboard_fault_test \
EXPECTED_UVM_ERRORS=6 \
EXPECTED_UVM_MARKER="UVM SCOREBOARD FAULT DETECTED" \
"${SCRIPT_DIR}/run_uvm_smoke.sh"
