#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-full}" in
    quick) baud_values=(8); wait_values=(0) ;;
    full) baud_values=(8 16); wait_values=(0 1 3) ;;
    *) echo "Usage: $0 [quick|full]" >&2; exit 2 ;;
esac

for baud in "${baud_values[@]}"; do
    for waits in "${wait_values[@]}"; do
        dir="build/uart/baud_${baud}_wait_${waits}"
        mkdir -p "$dir"
        if ! verilator --binary --timing --assert --top-module apb_uart_tb \
            -Wno-TIMESCALEMOD -GBAUD_DIV="$baud" -GWAIT_CYCLES="$waits" \
            --Mdir "$dir/obj" rtl/apb_uart.sv tb/apb_uart_tb.sv \
            >"$dir/compile.log" 2>&1; then
            cat "$dir/compile.log"
            exit 1
        fi
        if ! (cd "$dir"; ulimit -c 0; ./obj/Vapb_uart_tb) >"$dir/run.log" 2>&1; then
            cat "$dir/run.log"
            exit 1
        fi
        grep "^UART_PASS baud_div=$baud wait=$waits " "$dir/run.log"
    done
done
