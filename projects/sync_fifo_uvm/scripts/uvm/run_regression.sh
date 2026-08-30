#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

TOTAL_GROUPS=15
EXPECTED_POSITIVE_GROUPS=11
EXPECTED_NEGATIVE_GROUPS=4
PASS_COUNT=0
POSITIVE_PASS_COUNT=0
NEGATIVE_PASS_COUNT=0
REGRESSION_START_SECONDS="$(date +%s)"
TMP_BASE="${TMPDIR:-/tmp}"
TMP_BASE="${TMP_BASE%/}"

REGRESSION_LOG_DIR="${REGRESSION_LOG_DIR:-$(mktemp -d "${TMP_BASE}/digital_ic_fifo_uvm_regression.XXXXXX")}"
REGRESSION_SIM_DIR="${REGRESSION_SIM_DIR:-${REGRESSION_LOG_DIR}/sim}"
RANDOM_LOG_DIR="${REGRESSION_LOG_DIR}/random_regression"
SUMMARY_ROWS="${REGRESSION_LOG_DIR}/summary_rows.md"
SUMMARY_FILE="${PROJECT_ROOT}/reports/uvm_regression_summary.md"

mkdir -p "${REGRESSION_LOG_DIR}" "${REGRESSION_SIM_DIR}" "${RANDOM_LOG_DIR}" "${PROJECT_ROOT}/reports"
: > "${SUMMARY_ROWS}"

# Arguments: index, slug, title, positive|negative, runner, completion marker.
run_group() {
    local group_index="$1"
    local group_slug="$2"
    local group_title="$3"
    local group_kind="$4"
    local child_script="$5"
    local required_marker="$6"
    local group_dir="${REGRESSION_LOG_DIR}/${group_index}_${group_slug}"
    local runner_log="${group_dir}/runner.log"
    local group_start_seconds
    local group_end_seconds
    local elapsed_seconds
    local kind_label

    case "${group_kind}" in
        positive)
            kind_label="正向"
            ;;
        negative)
            kind_label="预期负向"
            ;;
        *)
            printf 'UVM REGRESSION FAIL: invalid group kind %s for group %s.\n' \
                "${group_kind}" "${group_index}" >&2
            exit 1
            ;;
    esac

    if [[ ! -x "${SCRIPT_DIR}/${child_script}" ]]; then
        printf 'UVM REGRESSION FAIL: child script is missing or not executable: %s\n' \
            "${child_script}" >&2
        exit 1
    fi

    mkdir -p "${group_dir}"
    group_start_seconds="$(date +%s)"
    printf '\n[%s/%s] %s（%s）\n' \
        "${group_index}" "${TOTAL_GROUPS}" "${group_title}" "${kind_label}"

    if env \
        -u BUILD_DIR \
        -u SIM_BINARY \
        -u SIM_LOG \
        -u COVERAGE_FILE \
        -u UVM_TESTNAME \
        -u UVM_COMPILE_SCOPE \
        -u UVM_VERBOSITY \
        -u UVM_RANDOM_TRANSACTIONS \
        -u VERILATOR_SEED \
        -u EXPECTED_UVM_MARKER \
        -u EXPECTED_UVM_WARNINGS \
        -u EXPECTED_UVM_ERRORS \
        -u EXPECTED_UVM_FATALS \
        -u EXPECTED_HARNESS_COMPLETION \
        SIM_DIR="${REGRESSION_SIM_DIR}" \
        RANDOM_LOG_DIR="${RANDOM_LOG_DIR}" \
        RANDOM_TRANSACTIONS=200 \
        "${SCRIPT_DIR}/${child_script}" 2>&1 | tee "${runner_log}"; then
        :
    else
        local child_status=$?
        printf 'UVM REGRESSION FAIL: group %s (%s) exited with status %s.\n' \
            "${group_index}" "${group_title}" "${child_status}" >&2
        printf 'Log: %s\n' "${runner_log}" >&2
        exit "${child_status}"
    fi

    if [[ "$(grep -Fxc -- "${required_marker}" "${runner_log}")" -ne 1 ]]; then
        printf 'UVM REGRESSION FAIL: group %s (%s) completion marker was missing or duplicated.\n' \
            "${group_index}" "${group_title}" >&2
        printf 'Required marker: %s\n' "${required_marker}" >&2
        printf 'Log: %s\n' "${runner_log}" >&2
        exit 1
    fi

    group_end_seconds="$(date +%s)"
    elapsed_seconds=$((group_end_seconds - group_start_seconds))
    PASS_COUNT=$((PASS_COUNT + 1))

    if [[ "${group_kind}" == "positive" ]]; then
        POSITIVE_PASS_COUNT=$((POSITIVE_PASS_COUNT + 1))
    else
        NEGATIVE_PASS_COUNT=$((NEGATIVE_PASS_COUNT + 1))
    fi

    printf '[%s/%s] PASS %s（%s，%ss）\n' \
        "${group_index}" "${TOTAL_GROUPS}" "${group_title}" "${kind_label}" "${elapsed_seconds}"
    printf '| %s | %s | %s | PASS | %s s |\n' \
        "${group_index}" "${group_title}" "${kind_label}" "${elapsed_seconds}" \
        >> "${SUMMARY_ROWS}"
}

run_group 1 "minimal_toolchain" "最小 UVM 工具链" "positive" \
    "run_uvm_smoke.sh" \
    "UVM RUNNER PASS: test=fifo_uvm_smoke_test scope=minimal warnings=0 errors=0 fatals=0 harness_completion=1"
run_group 2 "sequence_item" "sequence item 事务对象" "positive" \
    "run_uvm_item_smoke.sh" \
    "UVM RUNNER PASS: test=fifo_uvm_item_test scope=full warnings=0 errors=0 fatals=0 harness_completion=1"
run_group 3 "sequence_sequencer" "sequence 与 sequencer 握手" "positive" \
    "run_uvm_sequence_smoke.sh" \
    "UVM RUNNER PASS: test=fifo_uvm_sequence_test scope=full warnings=0 errors=0 fatals=0 harness_completion=1"
run_group 4 "driver_dut" "driver 与真实 DUT 集成" "positive" \
    "run_uvm_driver_smoke.sh" \
    "UVM RUNNER PASS: test=fifo_uvm_driver_test scope=full warnings=0 errors=0 fatals=0 harness_completion=1"
run_group 5 "monitor" "monitor 与 analysis port" "positive" \
    "run_uvm_monitor_smoke.sh" \
    "UVM RUNNER PASS: test=fifo_uvm_monitor_test scope=full warnings=0 errors=0 fatals=0 harness_completion=1"
run_group 6 "reference_model" "独立 reference model 合同" "positive" \
    "run_uvm_reference_model_smoke.sh" \
    "UVM RUNNER PASS: test=fifo_uvm_reference_model_test scope=full warnings=0 errors=0 fatals=0 harness_completion=1"
run_group 7 "scoreboard" "scoreboard 正向比较" "positive" \
    "run_uvm_scoreboard_smoke.sh" \
    "UVM RUNNER PASS: test=fifo_uvm_scoreboard_test scope=full warnings=0 errors=0 fatals=0 harness_completion=1"

run_group 8 "scoreboard_fault" "scoreboard 六字段故障注入" "negative" \
    "run_uvm_scoreboard_fault.sh" \
    "UVM RUNNER PASS: test=fifo_uvm_scoreboard_fault_test scope=full warnings=0 errors=6 fatals=0 harness_completion=1"

run_group 9 "active_environment" "主动 agent 与 environment" "positive" \
    "run_uvm_environment_smoke.sh" \
    "UVM RUNNER PASS: test=fifo_uvm_environment_test scope=full warnings=0 errors=0 fatals=0 harness_completion=1"
run_group 10 "passive_agent" "被动 agent 外部流量" "positive" \
    "run_uvm_passive_agent_smoke.sh" \
    "UVM RUNNER PASS: test=fifo_uvm_passive_agent_test scope=full warnings=0 errors=0 fatals=0 harness_completion=1"
run_group 11 "environment_topology_fault" "environment 漏接订阅者故障" "negative" \
    "run_uvm_environment_topology_fault.sh" \
    "UVM RUNNER PASS: test=fifo_uvm_environment_topology_fault_test scope=full warnings=0 errors=0 fatals=1 harness_completion=0"

run_group 12 "directed_coverage" "16 笔定向覆盖闭合" "positive" \
    "run_uvm_coverage_smoke.sh" \
    "UVM RUNNER PASS: test=fifo_uvm_coverage_test scope=full warnings=0 errors=0 fatals=0 harness_completion=1"
run_group 13 "coverage_fault" "四类非法覆盖样本" "negative" \
    "run_uvm_coverage_fault.sh" \
    "UVM RUNNER PASS: test=fifo_uvm_coverage_fault_test scope=full warnings=0 errors=4 fatals=0 harness_completion=1"
run_group 14 "coverage_gate_fault" "随机覆盖门槛故障" "negative" \
    "run_uvm_random_coverage_gate_fault.sh" \
    "UVM RUNNER PASS: test=fifo_uvm_random_test scope=full warnings=0 errors=0 fatals=1 harness_completion=0"
run_group 15 "random_regression" "20-seed 随机回归与重放" "positive" \
    "run_uvm_random_regression.sh" \
    "UVM RANDOM REGRESSION PASS: seeds=20 random_per_seed=200 replay=pass"

REGRESSION_END_SECONDS="$(date +%s)"
TOTAL_ELAPSED_SECONDS=$((REGRESSION_END_SECONDS - REGRESSION_START_SECONDS))

if [[ "${PASS_COUNT}" -ne "${TOTAL_GROUPS}" ]] ||
   [[ "${POSITIVE_PASS_COUNT}" -ne "${EXPECTED_POSITIVE_GROUPS}" ]] ||
   [[ "${NEGATIVE_PASS_COUNT}" -ne "${EXPECTED_NEGATIVE_GROUPS}" ]]; then
    printf 'UVM REGRESSION FAIL: passed=%s/%s positive=%s/%s negative=%s/%s.\n' \
        "${PASS_COUNT}" "${TOTAL_GROUPS}" \
        "${POSITIVE_PASS_COUNT}" "${EXPECTED_POSITIVE_GROUPS}" \
        "${NEGATIVE_PASS_COUNT}" "${EXPECTED_NEGATIVE_GROUPS}" >&2
    exit 1
fi

{
    printf '# UVM Regression Summary\n\n'
    printf -- '- 生成时间：%s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf -- '- 结果：PASS（通过）\n'
    printf -- '- 总通过数：%s/%s\n' "${PASS_COUNT}" "${TOTAL_GROUPS}"
    printf -- '- 正向测试：%s/%s\n' "${POSITIVE_PASS_COUNT}" "${EXPECTED_POSITIVE_GROUPS}"
    printf -- '- 预期负向测试：%s/%s\n' "${NEGATIVE_PASS_COUNT}" "${EXPECTED_NEGATIVE_GROUPS}"
    printf -- '- 总耗时：%s s\n' "${TOTAL_ELAPSED_SECONDS}"
    printf -- '- 详细日志：保存在本次运行的临时目录中，不纳入仓库\n\n'
    printf '| 组号 | 测试 | 类型 | 结果 | 耗时 |\n'
    printf '|---|---|---|---|---:|\n'
    while IFS= read -r summary_row; do
        printf '%s\n' "${summary_row}"
    done < "${SUMMARY_ROWS}"
    printf '\n'
    printf '> 预期负向测试的 PASS 表示验证环境准确检出了故意注入的错误，不表示被测设计发生了未处理失败。\n'
} > "${SUMMARY_FILE}"

printf '\nUVM REGRESSION PASS: 15/15 UVM FIFO groups passed (11 positive, 4 expected-negative).\n'
printf 'Summary: %s\n' "${SUMMARY_FILE}"
printf 'Logs: %s\n' "${REGRESSION_LOG_DIR}"
