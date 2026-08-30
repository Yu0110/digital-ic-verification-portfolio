#!/usr/bin/env bash

set -euo pipefail

# Verilator 开启断言后重跑同一套黑盒回归，检查四条接口级时序性质。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build/assertions"
OBJ_DIR="${BUILD_DIR}/obj"
SIM_BINARY="${BUILD_DIR}/round_robin_arbiter_sim"
COMPILE_LOG="${BUILD_DIR}/compile.log"
SIM_LOG="${BUILD_DIR}/simulation.log"

mkdir -p "${BUILD_DIR}"

if ! verilator --binary --sv --timing --assert --Wall \
    -DARBITER_ENABLE_SVA \
    --top-module round_robin_arbiter_tb \
    -Mdir "${OBJ_DIR}" \
    -o "${SIM_BINARY}" \
    "${PROJECT_ROOT}/rtl/round_robin_arbiter.sv" \
    "${PROJECT_ROOT}/tb/round_robin_arbiter_sva.sv" \
    "${PROJECT_ROOT}/tb/round_robin_arbiter_tb.sv" \
    >"${COMPILE_LOG}" 2>&1; then
    cat "${COMPILE_LOG}"
    exit 1
fi

"${SIM_BINARY}" | tee "${SIM_LOG}"
grep -q "ARBITER REGRESSION PASS" "${SIM_LOG}"

printf 'ARBITER SVA REGRESSION PASS: 4 properties, 0 failures\n'
