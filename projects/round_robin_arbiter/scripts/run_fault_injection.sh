#!/usr/bin/env bash

set -euo pipefail

# 在临时副本中应用错误补丁，正确结果必须是测试平台检出故障并返回非零状态。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build/faults/wrong_wrap_pointer"
WORK_ROOT="${BUILD_DIR}/work"
MUTANT_DIR="${WORK_ROOT}/projects/round_robin_arbiter/rtl"
MUTANT_RTL="${MUTANT_DIR}/round_robin_arbiter.sv"
SIM_BINARY="${BUILD_DIR}/round_robin_arbiter_fault.out"
SIM_LOG="${BUILD_DIR}/round_robin_arbiter_fault.log"
PATCH_FILE="${PROJECT_ROOT}/docs/bug_reports/BUG-INJECT-001_wrong_wrap_pointer.patch"

rm -rf "${WORK_ROOT}"
mkdir -p "${MUTANT_DIR}"
cp "${PROJECT_ROOT}/rtl/round_robin_arbiter.sv" "${MUTANT_RTL}"

(cd "${WORK_ROOT}" && patch --silent -p1 <"${PATCH_FILE}")

iverilog -g2012 -Wall \
    -s round_robin_arbiter_tb \
    -o "${SIM_BINARY}" \
    "${MUTANT_RTL}" \
    "${PROJECT_ROOT}/tb/round_robin_arbiter_tb.sv"

set +e
vvp "${SIM_BINARY}" >"${SIM_LOG}" 2>&1
SIM_STATUS=$?
set -e

cat "${SIM_LOG}"

if [[ "${SIM_STATUS}" -eq 0 ]]; then
    printf 'BUG-INJECT-001 FAILED: faulty wrap pointer escaped the regression.\n' >&2
    exit 1
fi

if ! grep -q "ARBITER REGRESSION FAILED" "${SIM_LOG}"; then
    printf 'BUG-INJECT-001 FAILED: simulation failed without the expected checker marker.\n' >&2
    exit 1
fi

printf 'BUG-INJECT-001 PASS: black-box scoreboard detected the intentional wrap defect.\n'
printf 'Faulty simulation exit code: %s (expected non-zero).\n' "${SIM_STATUS}"
