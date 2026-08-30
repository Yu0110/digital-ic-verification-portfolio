#!/usr/bin/env bash

set -euo pipefail

# 固定随机种子运行事务对象单元测试，确保约束分布结果可重复。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UVM_TESTNAME=fifo_uvm_item_test \
EXPECTED_UVM_MARKER="UVM SEQUENCE ITEM PASS" \
VERILATOR_SEED=20260830 \
"${SCRIPT_DIR}/run_uvm_smoke.sh"
