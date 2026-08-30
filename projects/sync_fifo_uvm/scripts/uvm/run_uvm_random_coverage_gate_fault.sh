#!/usr/bin/env bash

set -euo pipefail

# 仅生成一笔随机事务，确认覆盖率不足会阻止测试误报成功。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UVM_TESTNAME=fifo_uvm_random_test \
UVM_RANDOM_TRANSACTIONS=1 \
VERILATOR_SEED=20260830 \
EXPECTED_UVM_FATALS=1 \
EXPECTED_HARNESS_COMPLETION=0 \
EXPECTED_UVM_MARKER="random test failed:" \
"${SCRIPT_DIR}/run_uvm_smoke.sh"
