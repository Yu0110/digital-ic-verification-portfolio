#!/usr/bin/env bash

set -euo pipefail

# 验证 driver 的复位、单周期驱动和真实 DUT 状态更新。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UVM_TESTNAME=fifo_uvm_driver_test \
EXPECTED_UVM_MARKER="UVM DRIVER PASS" \
"${SCRIPT_DIR}/run_uvm_smoke.sh"
