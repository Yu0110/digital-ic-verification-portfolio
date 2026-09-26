#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
dir=build/protocol
mkdir -p "$dir"
echo "Compiling protocol checker tests"
if ! verilator --binary --timing --assert --top-module apb_protocol_tb \
    -Wno-TIMESCALEMOD --Mdir "$dir/obj" tb/apb_protocol_checker.sv \
    tb/apb_protocol_tb.sv >"$dir/compile.log" 2>&1; then
    cat "$dir/compile.log"; exit 1
fi
"$dir/obj/Vapb_protocol_tb" +case=legal >"$dir/legal.log" 2>&1
grep '^PROTOCOL_PASS setup=4 wait=2 done=3$' "$dir/legal.log"
for pair in no_setup:NO_SETUP enable_only:ENABLE_WITHOUT_SELECT \
    setup_addr:ADDR_STABLE setup_stuck:PHASE_HOLD \
    wait_addr:ADDR_STABLE wait_data:DATA_STABLE wait_dir:DIR_STABLE \
    wait_drop:PHASE_HOLD done_addr:ADDR_STABLE done_stuck:EXIT_ACCESS; do
    scenario="${pair%%:*}"
    marker="${pair#*:}"
    if (ulimit -c 0; "$dir/obj/Vapb_protocol_tb" "+case=$scenario") >"$dir/$scenario.log" 2>&1; then
        echo "Unexpected pass: $scenario"; exit 1
    fi
    grep -q "PROTO_$marker" "$dir/$scenario.log"
    echo "EXPECTED_PROTOCOL_ERROR case=$scenario marker=$marker"
done
