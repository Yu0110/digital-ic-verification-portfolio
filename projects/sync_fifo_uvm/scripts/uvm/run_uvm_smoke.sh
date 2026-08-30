#!/usr/bin/env bash

set -euo pipefail

# 通用 UVM 编译与运行入口；各子脚本通过环境变量选择测试和期望结果。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
UVM_HOME="${UVM_HOME:-${PROJECT_ROOT}/.deps/uvm}"
UVM_TESTNAME="${UVM_TESTNAME:-fifo_uvm_smoke_test}"
EXPECTED_UVM_MARKER="${EXPECTED_UVM_MARKER:-UVM SMOKE PASS}"
EXPECTED_UVM_WARNINGS="${EXPECTED_UVM_WARNINGS:-0}"
EXPECTED_UVM_ERRORS="${EXPECTED_UVM_ERRORS:-0}"
EXPECTED_UVM_FATALS="${EXPECTED_UVM_FATALS:-0}"
EXPECTED_HARNESS_COMPLETION="${EXPECTED_HARNESS_COMPLETION:-1}"
UVM_VERBOSITY="${UVM_VERBOSITY:-UVM_MEDIUM}"
UVM_RANDOM_TRANSACTIONS="${UVM_RANDOM_TRANSACTIONS:-}"
VERILATOR_SEED="${VERILATOR_SEED:-}"
UVM_COMPILE_SCOPE="${UVM_COMPILE_SCOPE:-auto}"

SIM_DIR="${SIM_DIR:-/tmp/fifo_uvm_smoke}"

mkdir -p "${SIM_DIR}"

if [[ ! -f "${UVM_HOME}/src/uvm_pkg.sv" ||
      ! -f "${UVM_HOME}/src/uvm_macros.svh" ||
      ! -f "${UVM_HOME}/src/dpi/uvm_dpi.cc" ]]; then
    printf 'ERROR: UVM library is missing. Run %s/scripts/setup_uvm.sh first.\n' \
           "${PROJECT_ROOT}" >&2
    exit 1
fi

if [[ "${UVM_COMPILE_SCOPE}" == "auto" ]]; then
    if [[ "${UVM_TESTNAME}" == "fifo_uvm_smoke_test" ]]; then
        UVM_COMPILE_SCOPE="minimal"
    else
        UVM_COMPILE_SCOPE="full"
    fi
fi

# 最小工具链测试与完整 FIFO 环境分开编译，降低首次自检成本。
case "${UVM_COMPILE_SCOPE}" in
    minimal)
        if [[ "${UVM_TESTNAME}" != "fifo_uvm_smoke_test" ]]; then
            printf 'ERROR: minimal UVM compile scope only contains fifo_uvm_smoke_test; requested %s.\n' \
                   "${UVM_TESTNAME}" >&2
            exit 1
        fi

        TOP_MODULE="fifo_uvm_minimal_smoke_tb"
        PROJECT_SOURCES=(
            "${PROJECT_ROOT}/uvm/fifo_uvm_smoke_pkg.sv"
            "${PROJECT_ROOT}/uvm/fifo_uvm_minimal_smoke_tb.sv"
        )
        ;;
    full)
        TOP_MODULE="fifo_uvm_smoke_tb"
        PROJECT_SOURCES=(
            "${PROJECT_ROOT}/tb/fifo_if.sv"
            "${PROJECT_ROOT}/uvm/fifo_uvm_pkg.sv"
            "${PROJECT_ROOT}/tb/non_uvm/fifo_sva_checker.sv"
            "${PROJECT_ROOT}/rtl/sync_fifo.sv"
            "${PROJECT_ROOT}/uvm/fifo_uvm_smoke_tb.sv"
        )
        ;;
    *)
        printf 'ERROR: UVM_COMPILE_SCOPE must be auto, minimal, or full; got %s.\n' \
               "${UVM_COMPILE_SCOPE}" >&2
        exit 1
        ;;
esac

if [[ "${UVM_COMPILE_SCOPE}" == "minimal" ]]; then
    DEFAULT_BUILD_DIR="${SIM_DIR}/obj_minimal"
    DEFAULT_SIM_BINARY="${SIM_DIR}/fifo_uvm_minimal_smoke_sim"
    DEFAULT_SIM_LOG="${SIM_DIR}/fifo_uvm_minimal_smoke.log"
    DEFAULT_COVERAGE_FILE="${SIM_DIR}/fifo_uvm_minimal_coverage.dat"
else
    DEFAULT_BUILD_DIR="${SIM_DIR}/obj"
    DEFAULT_SIM_BINARY="${SIM_DIR}/fifo_uvm_smoke_sim"
    DEFAULT_SIM_LOG="${SIM_DIR}/fifo_uvm_smoke.log"
    DEFAULT_COVERAGE_FILE="${SIM_DIR}/fifo_uvm_coverage.dat"
fi

BUILD_DIR="${BUILD_DIR:-${DEFAULT_BUILD_DIR}}"
SIM_BINARY="${SIM_BINARY:-${DEFAULT_SIM_BINARY}}"
SIM_LOG="${SIM_LOG:-${DEFAULT_SIM_LOG}}"
COVERAGE_FILE="${COVERAGE_FILE:-${DEFAULT_COVERAGE_FILE}}"

mkdir -p "${BUILD_DIR}"

# 编译 UVM 直接编程接口，并启用断言与用户覆盖率支持。
VERILATOR_ARGS=(
    --binary
    --sv
    --timing
    --assert
    --vpi
    --coverage-user
    -j
    0
    --quiet-build
)

if [[ "${UVM_COMPILE_SCOPE}" == "full" ]]; then
    VERILATOR_ARGS+=("-DFIFO_ENABLE_CLOCKING_BLOCKS")
fi

verilator "${VERILATOR_ARGS[@]}" \
    -I"${UVM_HOME}/src" \
    -I"${PROJECT_ROOT}/uvm" \
    -CFLAGS "-I${PROJECT_ROOT}/scripts/uvm_compat -I${UVM_HOME}/src/dpi -Wno-unknown-warning-option -Wno-deprecated-declarations" \
    -Wno-DECLFILENAME \
    -Wno-TIMESCALEMOD \
    --top-module "${TOP_MODULE}" \
    -Mdir "${BUILD_DIR}" \
    -o "${SIM_BINARY}" \
    "${UVM_HOME}/src/uvm_pkg.sv" \
    "${PROJECT_SOURCES[@]}" \
    "${UVM_HOME}/src/dpi/uvm_dpi.cc"

SIM_ARGS=(
    "+UVM_TESTNAME=${UVM_TESTNAME}"
    "+UVM_VERBOSITY=${UVM_VERBOSITY}"
    "+verilator+coverage+file+${COVERAGE_FILE}"
    "+UVM_NO_RELNOTES"
)

if [[ -n "${UVM_RANDOM_TRANSACTIONS}" ]]; then
    SIM_ARGS+=("+UVM_RANDOM_TRANSACTIONS=${UVM_RANDOM_TRANSACTIONS}")
fi

if [[ -n "${VERILATOR_SEED}" ]]; then
    SIM_ARGS+=("+verilator+seed+${VERILATOR_SEED}")
fi

if "${SIM_BINARY}" "${SIM_ARGS[@]}" 2>&1 | tee "${SIM_LOG}"; then
    :
else
    SIM_STATUS=$?
    printf 'ERROR: UVM simulation exited with status %s. Log: %s\n' \
           "${SIM_STATUS}" "${SIM_LOG}" >&2
    exit "${SIM_STATUS}"
fi

# Verilator may return zero after a UVM fatal, so validate report counts explicitly.
if [[ "$(grep -Ec "^UVM_WARNING[[:space:]]*:[[:space:]]*${EXPECTED_UVM_WARNINGS}[[:space:]]*$" "${SIM_LOG}")" -ne 1 ]]; then
    printf 'ERROR: UVM report did not contain exactly one UVM_WARNING : %s summary.\n' \
           "${EXPECTED_UVM_WARNINGS}" >&2
    exit 1
fi

if [[ "$(grep -Ec "^UVM_ERROR[[:space:]]*:[[:space:]]*${EXPECTED_UVM_ERRORS}[[:space:]]*$" "${SIM_LOG}")" -ne 1 ]]; then
    printf 'ERROR: UVM report did not contain exactly one UVM_ERROR : %s summary.\n' \
           "${EXPECTED_UVM_ERRORS}" >&2
    exit 1
fi

if [[ "$(grep -Ec "^UVM_FATAL[[:space:]]*:[[:space:]]*${EXPECTED_UVM_FATALS}[[:space:]]*$" "${SIM_LOG}")" -ne 1 ]]; then
    printf 'ERROR: UVM report did not contain exactly one UVM_FATAL : %s summary.\n' \
           "${EXPECTED_UVM_FATALS}" >&2
    exit 1
fi

if [[ "$(grep -F -c -- "${EXPECTED_UVM_MARKER}" "${SIM_LOG}")" -ne 1 ]]; then
    printf 'ERROR: expected UVM marker must appear exactly once: %s\n' \
           "${EXPECTED_UVM_MARKER}" >&2
    exit 1
fi

case "${EXPECTED_HARNESS_COMPLETION}" in
    1)
        if [[ "$(grep -Fxc "UVM TEST HARNESS PASS: selected test completed all phases" "${SIM_LOG}")" -ne 1 ]]; then
            printf 'ERROR: UVM test harness completion marker is missing or duplicated.\n' >&2
            exit 1
        fi
        ;;
    0)
        if [[ "$(grep -Fxc "UVM TEST HARNESS PASS: selected test completed all phases" "${SIM_LOG}")" -ne 0 ]]; then
            printf 'ERROR: an expected-fatal test unexpectedly reached the harness completion marker.\n' >&2
            exit 1
        fi
        ;;
    *)
        printf 'ERROR: EXPECTED_HARNESS_COMPLETION must be 0 or 1; got %s.\n' \
               "${EXPECTED_HARNESS_COMPLETION}" >&2
        exit 1
        ;;
esac

if [[ "${UVM_COMPILE_SCOPE}" == "full" ]]; then
    case "${EXPECTED_HARNESS_COMPLETION}" in
        1)
            if [[ "$(grep -Fc "UVM SVA CHECK PASS: failures=0" "${SIM_LOG}")" -ne 1 ]]; then
                printf 'ERROR: full UVM run did not complete exactly one zero-failure SVA check.\n' >&2
                exit 1
            fi
            ;;
        0)
            if [[ "$(grep -Fc "UVM SVA CHECK PASS: failures=0" "${SIM_LOG}")" -ne 0 ]]; then
                printf 'ERROR: expected-fatal UVM run unexpectedly reached the SVA completion check.\n' >&2
                exit 1
            fi
            ;;
    esac
fi

if [[ "${UVM_COMPILE_SCOPE}" == "minimal" ]]; then
    if [[ "$(grep -Fxc "UVM MINIMAL TOOLCHAIN PASS: factory=1 build_phase=1 run_phase=1 objection=1 elapsed_ns=1" "${SIM_LOG}")" -ne 1 ]]; then
        printf 'ERROR: minimal UVM toolchain completion marker is missing or duplicated.\n' >&2
        exit 1
    fi
fi

printf 'UVM RUNNER PASS: test=%s scope=%s warnings=%s errors=%s fatals=%s harness_completion=%s\n' \
       "${UVM_TESTNAME}" \
       "${UVM_COMPILE_SCOPE}" \
       "${EXPECTED_UVM_WARNINGS}" \
       "${EXPECTED_UVM_ERRORS}" \
       "${EXPECTED_UVM_FATALS}" \
       "${EXPECTED_HARNESS_COMPLETION}"
printf 'Simulation log: %s\n' "${SIM_LOG}"
