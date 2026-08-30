#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-${PROJECT_ROOT}/build/layered}"

mkdir -p "${BUILD_ROOT}"

run_config() {
    local data_width="$1"
    local depth="$2"
    local label="${data_width}x${depth}"
    local build_dir="${BUILD_ROOT}/${label}"
    local obj_dir="${build_dir}/obj"
    local sim_binary="${build_dir}/fifo_layered_sim"
    local sim_log="${build_dir}/fifo_layered.log"
    local required_marker

    mkdir -p "${build_dir}"
    required_marker="BOUNDARY INTEGRATION PASS: DATA_WIDTH=${data_width} DEPTH=${depth}"

    printf '\n=== Non-UVM layered regression DATA_WIDTH=%s DEPTH=%s ===\n' \
        "${data_width}" "${depth}"

    verilator --binary --sv --timing --assert \
        -Wno-DECLFILENAME \
        -Wno-TIMESCALEMOD \
        -DFIFO_ENABLE_CLOCKING_BLOCKS \
        --top-module fifo_boundary_integration_tb \
        -GDATA_WIDTH="${data_width}" \
        -GDEPTH="${depth}" \
        -Mdir "${obj_dir}" \
        -o "${sim_binary}" \
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

    "${sim_binary}" 2>&1 | tee "${sim_log}"

    if [[ "$(grep -Fc "${required_marker}" "${sim_log}")" -ne 1 ]]; then
        printf 'LAYERED REGRESSION FAIL: completion marker missing for %s.\n' \
            "${label}" >&2
        exit 1
    fi
}

run_config 8 3
run_config 8 4
run_config 16 4
run_config 8 5
run_config 8 6

printf '\nLAYERED REGRESSION PASS: 5/5 non-UVM configurations passed.\n'
