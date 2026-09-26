# Protocol Checker Walkthrough

[简体中文](protocol_walkthrough.md) | **English**

Read the task-level testbench, `tb/apb_protocol_checker.sv`, the dedicated `tb/apb_protocol_tb.sv`, then `scripts/run_protocol.sh`.

The checker stores `prev_setup`, `prev_wait`, `prev_done`, and the prior address, direction, and data. At each rising edge it checks current values against history before updating history. Otherwise it would compare a value with itself.

- After SETUP: enter ACCESS and preserve the request.
- After a waiting ACCESS: remain in ACCESS and preserve the request, including on the final ready edge.
- After completion: PENABLE must be low; either IDLE or the next SETUP may follow.

Reset clears phase history and cancels the previous hold obligation. Branch counters retain cumulative hits; they demonstrate exercised checks, not a complete functional coverage model. Checks are procedural immediate assertions, compiled with `--assert`, not concurrent properties.

| Case | Injected violation | Diagnostic suffix (PROTO_) |
|---|---|---|
| no_setup | Enter ACCESS without SETUP | NO_SETUP |
| enable_only | PENABLE without PSEL under the single-peripheral restriction | ENABLE_WITHOUT_SELECT |
| setup_addr | Change address between SETUP and ACCESS | ADDR_STABLE |
| setup_stuck | Remain in SETUP for two cycles | PHASE_HOLD |
| wait_addr | Change address while waiting | ADDR_STABLE |
| wait_data | Change write data while waiting | DATA_STABLE |
| wait_dir | Change direction while waiting | DIR_STABLE |
| wait_drop | Withdraw a waiting request | PHASE_HOLD |
| done_addr | Change address on the completion edge | ADDR_STABLE |
| done_stuck | Remain in ACCESS after completion | EXIT_ACCESS |

These are deliberately constructed checker tests, not ten discovered DUT defects. Legal traces include zero wait, waits, back-to-back transfers, changing unused write data on reads, and reset during a wait.

Run `make protocol` or `make regression`. Logs are in `build/protocol/`. A negative test must fail with its designated marker; an unrelated failure or timeout is insufficient.

The protocol checker, data scoreboard, and basic internal-register checks have different responsibilities. None replaces the others.
