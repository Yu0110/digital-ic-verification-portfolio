# Four-requester Round-robin Arbiter Verification

[简体中文](README.md) | **English**

This project implements and verifies a four-requester round-robin arbiter. The design provides one-hot-or-zero combinational grants and advances its search pointer after each nonzero grant. Verification is intentionally black-box: the reference model and checkers observe only public ports and never read the internal pointer.

## Published Evidence

| Verification layer | Result | Evidence |
|---|---|---|
| RTL lint | PASS | Verilator `--lint-only --Wall`, zero design warnings |
| Exhaustive selection | PASS | All 64 combinations of 4 pointer states and 16 request vectors |
| State transition | PASS | 64 black-box next-state probes |
| Bounded fairness | PASS | All 60 start-state/nonempty-request-set scenarios |
| Automated checks | PASS | 1,712 reference-model and invariant comparisons |
| Assertions | PASS | 4 SVA properties, zero failures |
| Fault injection | PASS | Intentional requester-3 wrap defect detected |

SVA = SystemVerilog Assertions.

## Architecture

- `req[3:0]` identifies active requesters.
- `grant[3:0]` is zero or one-hot and never grants an inactive requester.
- A two-bit pointer identifies where the next circular search starts.
- Combinational logic selects the first active requester from that start point.
- Sequential logic advances the pointer to the position after the selected requester.
- With no active request, the pointer remains unchanged.

The baseline interface treats every nonzero grant as an accepted service. A production integration with backpressure would advance the pointer only after an explicit acceptance handshake.

## Run

From this directory:

```bash
make directed    # Icarus Verilog black-box exhaustive regression
make assertions  # Verilator regression with SVA enabled
make faults      # Expected-failure fault-injection test
make verify      # Complete publishable suite
make wave        # Directed regression with a VCD waveform
```

VCD = Value Change Dump.

## Repository Layout

```text
round_robin_arbiter/
├── rtl/                       Synthesizable design
├── tb/                        Reference model, scoreboard, and SVA
├── scripts/                   Reproducible verification entry points
├── docs/                      Specification, plan, matrix, and results
├── reports/                   Generated release summary
├── Makefile                   Stable user-facing commands
├── README.md                  Simplified Chinese project page
└── README.en.md               English project page
```

Start with [`docs/reading_order.md`](docs/reading_order.md). The latest evidence is recorded in [`reports/full_verification_summary.md`](reports/full_verification_summary.md).

## Current Scope

- Four requesters, fixed width
- Active-low asynchronous reset
- Combinational grant output
- Grant implies service completion
- Single shared resource

Parameterization and an explicit grant-accept handshake are reasonable extensions, but are deliberately outside this small module's verified contract.
