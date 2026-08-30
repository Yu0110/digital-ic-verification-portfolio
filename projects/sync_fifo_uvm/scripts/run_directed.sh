#!/usr/bin/env bash

set -euo pipefail

# 使用 Icarus Verilog 对五组参数执行同一套自检式定向测试。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build/directed}"

mkdir -p "${BUILD_DIR}"

run_config() {
    local name="$1"
    local data_width="$2"
    local depth="$3"
    local sim_binary="${BUILD_DIR}/sync_fifo_${name}.out"
    local sim_log="${BUILD_DIR}/sync_fifo_${name}.log"
    local wave_file="${BUILD_DIR}/sync_fifo_${name}.vcd"
    local wave_name
    wave_name="$(basename "${wave_file}")"

    printf '\n=== Directed regression DATA_WIDTH=%s DEPTH=%s ===\n' \
        "${data_width}" "${depth}"

    iverilog -g2012 -Wall \
        -s sync_fifo_tb \
        -Psync_fifo_tb.DATA_WIDTH="${data_width}" \
        -Psync_fifo_tb.DEPTH="${depth}" \
        -o "${sim_binary}" \
        "${PROJECT_ROOT}/rtl/sync_fifo.sv" \
        "${PROJECT_ROOT}/tb/sync_fifo_tb.sv"

    if (
        cd "${BUILD_DIR}"
        vvp "${sim_binary}" "+VCD=${wave_name}"
    ) 2>&1 | tee "${sim_log}"; then
        :
    else
        local simulation_status=$?
        printf 'DIRECTED REGRESSION FAIL: configuration %s exited with status %s.\n' \
            "${name}" "${simulation_status}" >&2
        exit "${simulation_status}"
    fi

    # 退出码和唯一完成标记必须同时正确，防止提前结束被误判为通过。
    if [[ "$(grep -Fxc 'ALL DIRECTED TESTS PASSED' "${sim_log}")" -ne 1 ]]; then
        printf 'DIRECTED REGRESSION FAIL: completion marker missing for %s.\n' \
            "${name}" >&2
        exit 1
    fi
}

run_config "8x3" 8 3
run_config "8x4" 8 4
run_config "16x4" 16 4
run_config "8x5" 8 5
run_config "8x6" 8 6

printf '\nDIRECTED REGRESSION PASS: 5/5 parameter configurations passed.\n'
