#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ic-verification-portfolio.XXXXXX")"
RUN_FULL=0

usage() {
    cat <<'EOF'
Usage: ./scripts/run_all.sh [--full]

  no option  Run the round-robin arbiter test and FIFO directed regression.
  --full     Run the round-robin arbiter test and the complete FIFO suite.
  --help     Show this help message.
EOF
}

case "${1:-}" in
    "")
        ;;
    --full)
        RUN_FULL=1
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    *)
        printf 'ERROR: unknown option: %s\n\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac

if (( $# > 1 )); then
    printf 'ERROR: expected at most one option.\n\n' >&2
    usage >&2
    exit 2
fi

cleanup() {
    rm -rf "${BUILD_DIR}"
}

trap cleanup EXIT

printf '\n[1/2] Four-requester round-robin arbiter\n'
iverilog -g2012 -s round_robin_arbiter_tb \
    -o "${BUILD_DIR}/round_robin_arbiter.out" \
    "${ROOT_DIR}/projects/round_robin_arbiter/rtl/round_robin_arbiter.sv" \
    "${ROOT_DIR}/projects/round_robin_arbiter/tb/round_robin_arbiter_tb.sv"

(cd "${BUILD_DIR}" && vvp round_robin_arbiter.out)

if (( RUN_FULL == 1 )); then
    printf '\n[2/2] Parameterized synchronous FIFO: full verification suite\n'
    make -C "${ROOT_DIR}/projects/sync_fifo_uvm" verify
    printf '\nALL PORTFOLIO FULL TESTS PASSED: 2/2\n'
else
    printf '\n[2/2] Parameterized synchronous FIFO: directed regression\n'
    make -C "${ROOT_DIR}/projects/sync_fifo_uvm" directed
    printf '\nALL PORTFOLIO QUICK TESTS PASSED: 2/2\n'
fi
