#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DATA_WIDTH=8
DEPTH=5
BUILD_DIR="${PROJECT_ROOT}/build/faults/pointer_wrap"
OBJ_DIR="${BUILD_DIR}/obj"
SIM_BINARY="${BUILD_DIR}/fifo_bug_pointer_wrap_sim"
SIM_LOG="${BUILD_DIR}/fifo_bug_pointer_wrap.log"

mkdir -p "${BUILD_DIR}"

verilator --binary --sv --timing --assert \
    -Wno-DECLFILENAME \
    -Wno-TIMESCALEMOD \
    -DFIFO_ENABLE_CLOCKING_BLOCKS \
    -DFIFO_INJECT_BUG_002 \
    --top-module fifo_boundary_integration_tb \
    -GDATA_WIDTH="${DATA_WIDTH}" \
    -GDEPTH="${DEPTH}" \
    -Mdir "${OBJ_DIR}" \
    -o "${SIM_BINARY}" \
    "${PROJECT_ROOT}/tb/fifo_if.sv" \
    "${PROJECT_ROOT}/tb/non_uvm/fifo_transaction.sv" \
    "${PROJECT_ROOT}/tb/non_uvm/fifo_generator.sv" \
    "${PROJECT_ROOT}/tb/non_uvm/fifo_driver.sv" \
    "${PROJECT_ROOT}/tb/non_uvm/fifo_monitor.sv" \
    "${PROJECT_ROOT}/tb/non_uvm/fifo_reference_model.sv" \
    "${PROJECT_ROOT}/tb/non_uvm/fifo_scoreboard.sv" \
    "${PROJECT_ROOT}/tb/non_uvm/fifo_sva_checker.sv" \
    "${PROJECT_ROOT}/rtl/sync_fifo.sv" \
    "${PROJECT_ROOT}/tb/non_uvm/fifo_boundary_integration_tb.sv"

set +e
"${SIM_BINARY}" >"${SIM_LOG}" 2>&1
SIM_STATUS=$?
set -e

cat "${SIM_LOG}"

if [[ "${SIM_STATUS}" -eq 0 ]]; then
    printf '\nBUG-INJECT-002 FAILED: faulty pointer wrap escaped the boundary regression.\n' >&2
    exit 1
fi

if ! grep -q "SCOREBOARD ERROR" "${SIM_LOG}"; then
    printf '\nBUG-INJECT-002 FAILED: simulation failed without a scoreboard mismatch.\n' >&2
    exit 1
fi

if ! grep -q "BOUNDARY INTEGRATION FAILED DATA_WIDTH=8 DEPTH=5" "${SIM_LOG}"; then
    printf '\nBUG-INJECT-002 FAILED: expected boundary failure marker was absent.\n' >&2
    exit 1
fi

printf '\nBUG-INJECT-002 PASS: scoreboard detected the intentional pointer-wrap defect.\n'
printf 'Faulty simulation exit code: %s (expected non-zero).\n' "${SIM_STATUS}"
printf 'Failure log: %s\n' "${SIM_LOG}"
