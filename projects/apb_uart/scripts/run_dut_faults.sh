#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# 四个附加故障固定在 1 拍等待验证；提前写故障由 make faults 覆盖 0/1/3。
for fault in 1 2 3 4; do
    case "$fault" in
        1) marker='CHECK_FAIL error response';;
        2) marker='CHECK_FAIL commit exactly at completion';;
        3) marker='CHECK_FAIL asynchronous reset';;
        4) marker='CHECK_FAIL readback';;
    esac
    dir="build/dut_faults/fault_$fault"
    mkdir -p "$dir"
    echo "Compiling DUT fault=$fault wait=1"
    if ! verilator --binary --timing --top-module apb_regs_tb -Wno-TIMESCALEMOD \
        -GWAIT_CYCLES=1 -GINJECT_FAULT="$fault" --Mdir "$dir/obj" \
        rtl/apb_regs.sv tb/apb_regs_tb.sv >"$dir/compile.log" 2>&1; then
        cat "$dir/compile.log"; exit 1
    fi
    if (ulimit -c 0; "$dir/obj/Vapb_regs_tb") >"$dir/run.log" 2>&1; then
        echo "DUT fault unexpectedly passed: $fault"; exit 1
    fi
    grep -q "$marker" "$dir/run.log"
    echo "EXPECTED_DUT_ERROR fault=$fault wait=1 marker=$marker"
done
