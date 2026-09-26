#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-test}"
case "$mode" in test|faults|wave) ;; *) echo "Unknown mode: $mode" >&2; exit 2;; esac
bug=0
[[ "$mode" != faults ]] || bug=1
for waits in 0 1 3; do
    dir="build/$mode/wait_$waits"
    mkdir -p "$dir"
    echo "Compiling $mode test: wait=$waits"
    if ! verilator --binary --timing --trace --top-module apb_regs_tb -Wno-TIMESCALEMOD \
        -GWAIT_CYCLES="$waits" -GINJECT_EARLY_WRITE="$bug" \
        --Mdir "$dir/obj" rtl/apb_regs.sv tb/apb_regs_tb.sv >"$dir/compile.log" 2>&1; then
        cat "$dir/compile.log"; exit 1
    fi
    set +e
    (cd "$dir"; ulimit -c 0
        if [[ "$mode" == wave ]]; then ./obj/Vapb_regs_tb +wave
        else ./obj/Vapb_regs_tb; fi
    ) >"$dir/run.log" 2>&1
    status=$?
    set -e
    if [[ "$mode" == faults ]]; then
        if [[ $status -eq 0 ]] || ! grep -q 'CHECK_FAIL no setup write' "$dir/run.log"; then
            cat "$dir/run.log"; echo "FAULT_CHECK_FAILED"; exit 1
        fi
        echo "EXPECTED_FAULT_DETECTED wait=$waits"
    else
        if [[ $status -ne 0 ]] || ! grep -q "^APB_PASS wait=$waits transfers=20 checks=" "$dir/run.log"; then
            cat "$dir/run.log"; exit 1
        fi
        grep '^APB_PASS ' "$dir/run.log"
    fi
done
