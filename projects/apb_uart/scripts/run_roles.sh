#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for waits in 0 1 3; do
    dir="build/roles/wait_$waits"
    mkdir -p "$dir"
    echo "Compiling roles test: wait=$waits"
    if ! verilator --binary --timing --assert --top-module apb_roles_tb -Wno-TIMESCALEMOD \
        -GWAIT_CYCLES="$waits" --Mdir "$dir/obj" \
        rtl/apb_regs.sv tb/apb_protocol_checker.sv tb/apb_roles_tb.sv >"$dir/compile.log" 2>&1; then
        cat "$dir/compile.log"; exit 1
    fi
    "$dir/obj/Vapb_roles_tb" >"$dir/run.log" 2>&1
    grep "^ROLES_PASS wait=$waits observed=9$" "$dir/run.log"
    grep '^REQUESTS_PASS planned=9 matched=9 pending=0$' "$dir/run.log"
    if (ulimit -c 0; "$dir/obj/Vapb_roles_tb" +corrupt_read) >"$dir/negative.log" 2>&1; then
        echo "Negative test unexpectedly passed"; exit 1
    fi
    grep -q 'SCORE_READBACK addr=00 actual=0000002b expected=0000002a' "$dir/negative.log"
    echo "EXPECTED_READBACK_ERROR wait=$waits"
    # 故障必须命中请求匹配错误，不能靠超时或其他失败混过关。
    for pair in address:REQUEST_ADDR direction:REQUEST_DIR data:REQUEST_DATA \
        drop:REQUEST_MISSING duplicate:REQUEST_UNEXPECTED; do
        fault="${pair%%:*}"
        marker="${pair#*:}"
        if (ulimit -c 0; "$dir/obj/Vapb_roles_tb" "+request_fault=$fault") \
            >"$dir/request_$fault.log" 2>&1; then
            echo "Request fault unexpectedly passed: $fault"; exit 1
        fi
        grep -q "$marker" "$dir/request_$fault.log"
        echo "EXPECTED_REQUEST_ERROR wait=$waits case=$fault marker=$marker"
    done
done
