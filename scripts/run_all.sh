#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ic-verification-portfolio.XXXXXX")"

cleanup() {
    rm -rf "${BUILD_DIR}"
}

trap cleanup EXIT

iverilog -g2012 -s round_robin_arbiter_tb \
    -o "${BUILD_DIR}/round_robin_arbiter.out" \
    "${ROOT_DIR}/projects/round_robin_arbiter/rtl/round_robin_arbiter.sv" \
    "${ROOT_DIR}/projects/round_robin_arbiter/tb/round_robin_arbiter_tb.sv"

(cd "${BUILD_DIR}" && vvp round_robin_arbiter.out)

echo "ALL PORTFOLIO TESTS PASSED: 1/1"
