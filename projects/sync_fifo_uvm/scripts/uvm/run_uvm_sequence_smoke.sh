#!/usr/bin/env bash

set -euo pipefail

# 隔离验证 sequence、sequencer 与模拟 sink 的事务握手。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UVM_TESTNAME=fifo_uvm_sequence_test \
EXPECTED_UVM_MARKER="UVM SEQUENCE PASS" \
"${SCRIPT_DIR}/run_uvm_smoke.sh"
