#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM_DIR="${SIM_DIR:-/tmp/fifo_uvm_smoke}"
SIM_BINARY="${SIM_BINARY:-${SIM_DIR}/fifo_uvm_smoke_sim}"
RANDOM_TRANSACTIONS="${RANDOM_TRANSACTIONS:-200}"
FIFO_DEPTH=4
RANDOM_LOG_DIR="${RANDOM_LOG_DIR:-${SIM_DIR}/random_regression}"

if [[ ! "${RANDOM_TRANSACTIONS}" =~ ^[1-9][0-9]*$ ]]; then
    printf 'ERROR: RANDOM_TRANSACTIONS must be a positive decimal integer; got %s.\n' \
           "${RANDOM_TRANSACTIONS}" >&2
    exit 1
fi

if (( ${#RANDOM_TRANSACTIONS} > 3 )) ||
   (( 10#${RANDOM_TRANSACTIONS} > 400 )); then
    printf 'ERROR: RANDOM_TRANSACTIONS must not exceed 400; got %s.\n' \
           "${RANDOM_TRANSACTIONS}" >&2
    exit 1
fi

mkdir -p "${RANDOM_LOG_DIR}"

if (( $# > 0 )); then
    SEEDS=("$@")
else
    SEEDS=(
        20260801 20260802 20260803 20260804 20260805
        20260806 20260807 20260808 20260809 20260810
        20260811 20260812 20260813 20260814 20260815
        20260816 20260817 20260818 20260819 20260820
    )
fi

SEEN_SEEDS=" "
for seed in "${SEEDS[@]}"; do
    if [[ ! "${seed}" =~ ^[1-9][0-9]*$ ]]; then
        printf 'ERROR: each seed must be a positive decimal integer; got %s.\n' \
               "${seed}" >&2
        exit 1
    fi

    if (( ${#seed} > 10 )) || (( 10#${seed} > 2147483647 )); then
        printf 'ERROR: seed must be in the range 1..2147483647; got %s.\n' \
               "${seed}" >&2
        exit 1
    fi

    case "${SEEN_SEEDS}" in
        *" ${seed} "*)
            printf 'ERROR: duplicate seed is not allowed: %s.\n' "${seed}" >&2
            exit 1
            ;;
    esac
    SEEN_SEEDS="${SEEN_SEEDS}${seed} "
done

validate_log() {
    local log_file="$1"
    local seed="$2"
    local expected_total
    local pass_pattern
    local coverage_pattern

    expected_total=$((RANDOM_TRANSACTIONS + FIFO_DEPTH))
    pass_pattern="UVM RANDOM TEST PASS: random=${RANDOM_TRANSACTIONS} drain=${FIFO_DEPTH} total=${expected_total} read=[0-9]+ write=[0-9]+ simultaneous=[0-9]+ digest=[0-9a-fA-F]{16}"
    coverage_pattern="UVM COVERAGE SUMMARY: received=${expected_total} samples=${expected_total} covergroup=100[.]00% goals_closed=1 errors=0"

    if [[ "$(grep -Ec "${pass_pattern}" "${log_file}")" -ne 1 ]] ||
       [[ "$(grep -Ec "${coverage_pattern}" "${log_file}")" -ne 1 ]] ||
       [[ "$(grep -Ec '^UVM_WARNING[[:space:]]*:[[:space:]]*0[[:space:]]*$' "${log_file}")" -ne 1 ]] ||
       [[ "$(grep -Ec '^UVM_ERROR[[:space:]]*:[[:space:]]*0[[:space:]]*$' "${log_file}")" -ne 1 ]] ||
       [[ "$(grep -Ec '^UVM_FATAL[[:space:]]*:[[:space:]]*0[[:space:]]*$' "${log_file}")" -ne 1 ]] ||
       [[ "$(grep -Fxc 'UVM TEST HARNESS PASS: selected test completed all phases' "${log_file}")" -ne 1 ]]; then
        printf 'ERROR: UVM random seed %s failed. Log: %s\n' "${seed}" "${log_file}" >&2
        tail -n 60 "${log_file}" >&2
        exit 1
    fi
}

run_compiled_seed() {
    local seed="$1"
    local suffix="$2"
    local log_file="${RANDOM_LOG_DIR}/fifo_uvm_random_seed_${seed}_${suffix}.log"
    local coverage_file="${RANDOM_LOG_DIR}/fifo_uvm_random_seed_${seed}_${suffix}.dat"

    "${SIM_BINARY}" \
        +UVM_TESTNAME=fifo_uvm_random_test \
        +UVM_VERBOSITY=UVM_NONE \
        +UVM_NO_RELNOTES \
        "+UVM_RANDOM_TRANSACTIONS=${RANDOM_TRANSACTIONS}" \
        "+verilator+seed+${seed}" \
        "+verilator+coverage+file+${coverage_file}" \
        >"${log_file}" 2>&1

    validate_log "${log_file}" "${seed}"
    printf '%s\n' "${log_file}"
}

FIRST_SEED="${SEEDS[0]}"
FIRST_LOG="${RANDOM_LOG_DIR}/fifo_uvm_random_seed_${FIRST_SEED}_original.log"

printf 'Building and running UVM random seed %s (%s random transactions)...\n' \
       "${FIRST_SEED}" "${RANDOM_TRANSACTIONS}"

SIM_DIR="${SIM_DIR}" \
SIM_BINARY="${SIM_BINARY}" \
UVM_TESTNAME=fifo_uvm_random_test \
EXPECTED_UVM_MARKER="UVM RANDOM TEST PASS" \
UVM_VERBOSITY=UVM_NONE \
UVM_RANDOM_TRANSACTIONS="${RANDOM_TRANSACTIONS}" \
VERILATOR_SEED="${FIRST_SEED}" \
COVERAGE_FILE="${RANDOM_LOG_DIR}/fifo_uvm_random_seed_${FIRST_SEED}_original.dat" \
"${SCRIPT_DIR}/run_uvm_smoke.sh" >"${FIRST_LOG}" 2>&1

validate_log "${FIRST_LOG}" "${FIRST_SEED}"

if [[ ! -x "${SIM_BINARY}" ]]; then
    printf 'ERROR: compiled UVM simulation binary is missing or not executable: %s\n' \
           "${SIM_BINARY}" >&2
    exit 1
fi

FIRST_DIGEST="$(grep -Eo 'digest=[0-9a-fA-F]+' "${FIRST_LOG}" | tail -n 1 | cut -d= -f2)"
printf '[1/%s] PASS seed=%s digest=%s\n' "${#SEEDS[@]}" "${FIRST_SEED}" "${FIRST_DIGEST}"

for ((index = 1; index < ${#SEEDS[@]}; index++)); do
    seed="${SEEDS[index]}"
    log_file="$(run_compiled_seed "${seed}" original)"
    digest="$(grep -Eo 'digest=[0-9a-fA-F]+' "${log_file}" | tail -n 1 | cut -d= -f2)"
    printf '[%s/%s] PASS seed=%s digest=%s\n' \
           "$((index + 1))" "${#SEEDS[@]}" "${seed}" "${digest}"
done

REPLAY_LOG="$(run_compiled_seed "${FIRST_SEED}" replay)"
REPLAY_DIGEST="$(grep -Eo 'digest=[0-9a-fA-F]+' "${REPLAY_LOG}" | tail -n 1 | cut -d= -f2)"

if [[ -z "${FIRST_DIGEST}" || "${FIRST_DIGEST}" != "${REPLAY_DIGEST}" ]]; then
    printf 'ERROR: seed replay digest mismatch: first=%s replay=%s\n' \
           "${FIRST_DIGEST}" "${REPLAY_DIGEST}" >&2
    exit 1
fi

printf 'UVM RANDOM REPLAY PASS: seed=%s digest=%s\n' \
       "${FIRST_SEED}" "${FIRST_DIGEST}"
printf 'UVM RANDOM REGRESSION PASS: seeds=%s random_per_seed=%s replay=pass\n' \
       "${#SEEDS[@]}" "${RANDOM_TRANSACTIONS}"
