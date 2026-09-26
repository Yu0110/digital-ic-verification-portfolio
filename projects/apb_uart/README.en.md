# APB and UART Peripheral Verification

[简体中文](README.md) | **English**

The original two-register APB3 verification baseline has configurable waits, error responses, directed and pseudorandom tests, task-level driver/monitor roles, an independent reference model, request matching, protocol checks, and explicit coverage counters. A separate integrated UART extension adds real 8N1 serial TX/RX.

The original two-register APB teaching baseline remains intact. A separate APB-connected 8N1 UART peripheral and serial self-checking testbench are now included. Neither environment is class-based UVM. APB means Advanced Peripheral Bus; DUT means Design Under Test.

## Original APB Baseline Architecture

- 32-bit data, 8-bit byte addresses, one clock, active-low asynchronous reset.
- `0x00`: read/write DATA, reset value 0. `0x04`: read-only ID, value 1.
- Invalid/misaligned accesses and writes to ID return an error without changing DATA. Error reads return 0. These are project-specific peripheral semantics.
- A transfer completes on a rising edge with `PSEL && PENABLE && PREADY`. Completion and success are separate: the error response must also be checked.

```text
Planned requests -> driver -> DUT -> monitor -> request matcher -> scoreboard -> coverage
                                -> protocol checker (sampled phases and request stability)
```

Expected data is maintained from the specification, not copied from DUT internals. The basic testbench also checks internal register update timing to detect early writes that final readback alone can miss. The task-level monitor calls the scoreboard synchronously; it is not a class-based TLM environment.

## Run

Requirements: Verilator (tested with 5.050), a C++ compiler, GNU Make, and Bash. From the repository root:

```sh
make -C projects/apb_uart regression
```

| Command inside the project | Purpose |
|---|---|
| `make test` | Directed tests with 0/1/3 wait cycles |
| `make uart` | 8N1 TX/RX and APB tests across two baud divisors and three wait settings |
| `make uart-smoke` | One UART configuration for the portfolio quick regression |
| `make faults` | Early-write injection at all three wait settings |
| `make dut-faults` | Four additional DUT faults at wait=1 |
| `make roles` | Task-level environment, request matching, and negative tests |
| `make protocol` | Legal trace and ten protocol violations |
| `make random` | Seeds, coverage closure, replay, and coverage-gap rejection |
| `make lint` / `make wave` | RTL lint / basic waveform generation |
| `make regression` | Complete project suite, stopping on any failed check |

The integrated UART has one-byte transmit and receive paths, busy rejection, receive overrun and framing-error flags. It does not provide a FIFO, parity, flow control, or interrupts. See the [specification](spec.en.md) for its separate register map.

Build products, logs, and waveforms are generated in the Git-ignored `build/` directory. Negative tests require both a nonzero exit and the specific diagnostic. Compile failures and timeouts are not successful detections.

## Evidence

| Area | Current regression scope |
|---|---|
| Basic directed | 3 wait settings, 60 completed transfers, 542 checks |
| DUT faults | 5 injected classes: 3 early-write runs and 4 additional fault runs |
| Request faults / observation corruption | 15/15 / 3/3 detected |
| Protocol checker | Legal trace passes; 10/10 violations detected |
| Random suite | 3 seeds x 3 wait settings; 1,800 random requests, 1,971 total transfers including directed traffic |
| Functional coverage | Final 11/11 bins per run, including directed closure |
| Replay / gap rejection | 3 identical request-sequence replays; 3 deliberate 6/11 gaps rejected |
| APB + UART | 6 baud/wait configurations, 27 APB transfers per run; TX/RX loopback, overrun, framing, reset, and error handling |

The [historical publication regression](reports/publication_regression.en.md) covers the original APB baseline only. See the [UART regression](reports/uart_regression.en.md) for the new extension.

## Reading Order

1. [Specification](spec.en.md), [verification plan](verification_plan.en.md), and [test matrix](test_matrix.en.md).
2. [RTL](rtl/apb_regs.sv), [basic testbench](tb/apb_regs_tb.sv), and [write-commit explanation](notes.en.md).
3. [Task-level testbench](tb/apb_roles_tb.sv), [request matching](docs/request_matching.en.md), and [protocol checks](docs/protocol_walkthrough.en.md).
4. [Random testing and coverage](docs/random_coverage.en.md), [DUT faults](bug_reports/dut_fault_matrix.en.md), and [end-to-end walkthrough](docs/final_walkthrough.en.md).
5. [UART RTL](rtl/apb_uart.sv) and [UART self-checking testbench](tb/apb_uart_tb.sv).

## Limitations

- Single-peripheral APB3 signal subset; no shared multi-peripheral bus, byte strobes, or protection attributes.
- Task-level separation, not UVM; no class constraint solver, native covergroups, or concurrent protocol properties. Protocol checks use procedural immediate assertions and are compiled with `--assert`.
- Eleven explicit coverage bins are neither code coverage nor complete protocol coverage.
- Only wait settings 0/1/3 are tested; no arbitrary-parameter proof or per-transfer random wait duration.
- Mid-transfer reset is tested in the basic environment. The request-matching environment resets only between requests and has no explicit cancellation policy.
- Verilator runs do not establish complete four-state X/Z correctness. Between-edge glitches are outside the sampled checker scope.
- A write overwritten before readback is not fully checked by this bus-level model alone.
- All faults are deliberate injections, not defects discovered in commercial silicon or evidence of tapeout signoff.

This project uses AI-assisted development and grounds claims in runnable tests and explicit scope. Personal interview notes and machine-specific paths are excluded. Code retains explanatory Chinese comments, with bilingual core technical documentation.
