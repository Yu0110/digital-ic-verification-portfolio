#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for waits in 0 1 3; do
    dir="build/random/wait_$waits"
    mkdir -p "$dir"
    echo "Compiling random test: wait=$waits"
    if ! verilator --binary --timing --assert --top-module apb_roles_tb -Wno-TIMESCALEMOD \
        -GWAIT_CYCLES="$waits" --Mdir "$dir/obj" rtl/apb_regs.sv \
        tb/apb_protocol_checker.sv tb/apb_roles_tb.sv >"$dir/compile.log" 2>&1; then
        cat "$dir/compile.log"; exit 1
    fi
    for seed in 11 29 47; do
        "$dir/obj/Vapb_roles_tb" +coverage +random_count=200 "+seed=$seed" >"$dir/seed_$seed.log" 2>&1
        grep "^RANDOM_PASS seed=$seed wait=$waits random=200 observed=219 bins=11/11$" "$dir/seed_$seed.log"
        grep -q '^REQUESTS_PASS planned=219 matched=219 pending=0$' "$dir/seed_$seed.log"
    done
    # 相同种子重放，逐行对比全部随机请求，而不是仅比较最终 PASS。
    "$dir/obj/Vapb_roles_tb" +coverage +random_count=200 +seed=11 >"$dir/replay.log" 2>&1
    grep -q "^RANDOM_PASS seed=11 wait=$waits random=200 observed=219 bins=11/11$" "$dir/replay.log"
    grep '^RANDOM_REQ ' "$dir/seed_11.log" >"$dir/original_requests.txt"
    grep '^RANDOM_REQ ' "$dir/replay.log" >"$dir/replay_requests.txt"
    test "$(wc -l < "$dir/original_requests.txt" | tr -d ' ')" = 200
    cmp "$dir/original_requests.txt" "$dir/replay_requests.txt"
    echo "REPLAY_PASS wait=$waits seed=11 requests=200"
    # 不随机也不补齐：读写比较可通过，但覆盖门槛必须拒绝。
    if (ulimit -c 0; "$dir/obj/Vapb_roles_tb" +coverage +no_close +random_count=0) \
        >"$dir/coverage_gap.log" 2>&1; then
        echo 'Coverage gap unexpectedly passed'; exit 1
    fi
    grep -q '^REQUESTS_PASS planned=9 matched=9 pending=0$' "$dir/coverage_gap.log"
    grep -q 'COVERAGE_GAP hit=6 total=11' "$dir/coverage_gap.log"
    echo "EXPECTED_COVERAGE_GAP wait=$waits hit=6/11"
done
