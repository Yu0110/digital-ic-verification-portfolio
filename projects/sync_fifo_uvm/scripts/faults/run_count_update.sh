#!/usr/bin/env bash

set -euo pipefail

# 注入“同时读写时数量错误加一”，测试平台必须报告预期计数不匹配。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build/faults/count_update"
SIM_BINARY="${BUILD_DIR}/sync_fifo_bug_count_update.out"
SIM_LOG="${BUILD_DIR}/sync_fifo_bug_count_update.log"
VCD_FILE="${BUILD_DIR}/sync_fifo_bug_count_update.vcd"
VCD_NAME="$(basename "${VCD_FILE}")"

mkdir -p "${BUILD_DIR}"

iverilog -g2012 -Wall \
    -DFIFO_INJECT_BUG_001 \
    -s sync_fifo_tb \
    -o "${SIM_BINARY}" \
    "${PROJECT_ROOT}/rtl/sync_fifo.sv" \
    "${PROJECT_ROOT}/tb/sync_fifo_tb.sv"

# 故障仿真预期返回非零，因此临时关闭 shell 的立即退出行为。
set +e
(
    cd "${BUILD_DIR}"
    vvp "${SIM_BINARY}" "+VCD=${VCD_NAME}"
) >"${SIM_LOG}" 2>&1
SIM_STATUS=$?
set -e

cat "${SIM_LOG}"

if [[ "${SIM_STATUS}" -eq 0 ]]; then
    printf '\nBUG-INJECT-001 FAILED: the faulty count update escaped the directed testbench.\n' >&2
    exit 1
fi

if ! grep -q "ERROR read A and write C: data_count actual=3 expected=2" "${SIM_LOG}"; then
    printf '\nBUG-INJECT-001 FAILED: expected count mismatch was absent.\n' >&2
    exit 1
fi

if ! grep -q "DIRECTED TESTS FAILED" "${SIM_LOG}"; then
    printf '\nBUG-INJECT-001 FAILED: expected final failure marker was absent.\n' >&2
    exit 1
fi

printf '\nBUG-INJECT-001 PASS: directed testbench detected the intentional count-update defect.\n'
printf 'Faulty simulation exit code: %s (expected non-zero).\n' "${SIM_STATUS}"
printf 'Failure log: %s\n' "${SIM_LOG}"
