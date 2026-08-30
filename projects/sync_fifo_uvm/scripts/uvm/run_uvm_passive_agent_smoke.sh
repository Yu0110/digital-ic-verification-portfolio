#!/usr/bin/env bash

set -euo pipefail

# 验证被动 agent 只监视接口，不创建 sequencer 和 driver。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

UVM_TESTNAME=fifo_uvm_passive_agent_test \
EXPECTED_UVM_MARKER="UVM PASSIVE AGENT PASS" \
"${SCRIPT_DIR}/run_uvm_smoke.sh"
