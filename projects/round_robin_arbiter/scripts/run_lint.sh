#!/usr/bin/env bash

set -euo pipefail

# 单独检查可综合 RTL，避免测试平台代码掩盖设计层告警。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

verilator --lint-only --sv --Wall \
    --top-module round_robin_arbiter \
    "${PROJECT_ROOT}/rtl/round_robin_arbiter.sv"

printf 'ARBITER RTL LINT PASS\n'
