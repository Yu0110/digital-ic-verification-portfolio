#!/usr/bin/env bash

set -euo pipefail

# 用手工期望值隔离验证参考模型的队列行为和边界规则。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UVM_TESTNAME=fifo_uvm_reference_model_test \
EXPECTED_UVM_MARKER="UVM REFERENCE MODEL PASS" \
"${SCRIPT_DIR}/run_uvm_smoke.sh"
