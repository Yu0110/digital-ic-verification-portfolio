#!/usr/bin/env bash

set -euo pipefail

# Icarus Verilog 回归覆盖全部 64 个状态/请求组合和 60 个公平性场景。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build/directed"
SIM_BINARY="${BUILD_DIR}/round_robin_arbiter.out"
SIM_LOG="${BUILD_DIR}/round_robin_arbiter.log"

mkdir -p "${BUILD_DIR}"

iverilog -g2012 -Wall \
    -s round_robin_arbiter_tb \
    -o "${SIM_BINARY}" \
    "${PROJECT_ROOT}/rtl/round_robin_arbiter.sv" \
    "${PROJECT_ROOT}/tb/round_robin_arbiter_tb.sv"

if [[ "${DUMP_WAVE:-0}" == "1" ]]; then
    (cd "${BUILD_DIR}" && vvp "${SIM_BINARY}" +dump) | tee "${SIM_LOG}"
else
    vvp "${SIM_BINARY}" | tee "${SIM_LOG}"
fi

grep -q "ARBITER REGRESSION PASS" "${SIM_LOG}"
grep -q "exhaustive state/req cross  : 64/64" "${SIM_LOG}"
grep -q "persistent fairness cases   : 60/60" "${SIM_LOG}"

printf 'ARBITER DIRECTED REGRESSION PASS\n'
if [[ "${DUMP_WAVE:-0}" == "1" ]]; then
    printf 'Waveform: %s\n' "${BUILD_DIR}/round_robin_arbiter.vcd"
fi
