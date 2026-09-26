#!/usr/bin/env bash

set -euo pipefail

# 作品集统一入口：默认执行三个项目的快速回归，--full 执行完整验证套件。
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_FULL=0

usage() {
    cat <<'EOF'
Usage: ./scripts/run_all.sh [--full]

  no option  Run the arbiter, FIFO, APB, and UART directed/smoke regressions.
  --full     Run the complete arbiter, FIFO, APB, and UART suites.
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

if (( RUN_FULL == 1 )); then
    printf '\n[1/3] Four-requester round-robin arbiter: full verification suite\n'
    make -C "${ROOT_DIR}/projects/round_robin_arbiter" verify
    printf '\n[2/3] Parameterized synchronous FIFO: full verification suite\n'
    make -C "${ROOT_DIR}/projects/sync_fifo_uvm" verify
    printf '\n[3/3] APB and UART peripheral: full verification suite\n'
    make -C "${ROOT_DIR}/projects/apb_uart" regression
    printf '\nALL PORTFOLIO FULL TESTS PASSED: 3/3\n'
else
    printf '\n[1/3] Four-requester round-robin arbiter: exhaustive directed regression\n'
    make -C "${ROOT_DIR}/projects/round_robin_arbiter" directed
    printf '\n[2/3] Parameterized synchronous FIFO: directed regression\n'
    make -C "${ROOT_DIR}/projects/sync_fifo_uvm" directed
    printf '\n[3/3] APB and UART peripheral: directed regression and serial smoke\n'
    make -C "${ROOT_DIR}/projects/apb_uart" test
    make -C "${ROOT_DIR}/projects/apb_uart" uart-smoke
    printf '\nALL PORTFOLIO QUICK TESTS PASSED: 3/3\n'
fi
