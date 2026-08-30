#!/usr/bin/env bash

set -euo pipefail

# 运行预期负向覆盖率测试，四个未命中目标必须被报告为错误。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UVM_TESTNAME=fifo_uvm_coverage_fault_test \
EXPECTED_UVM_ERRORS=4 \
EXPECTED_UVM_MARKER="UVM COVERAGE FAULT DETECTED" \
"${SCRIPT_DIR}/run_uvm_smoke.sh"
