# APB Register Peripheral Verification

[简体中文](README.md) | **English**

A reproducible, single-peripheral APB3 verification project with two registers, configurable wait states, error responses, directed and pseudorandom tests, task-level drivers and monitors, an independent reference model, request matching, protocol checks, and explicit functional coverage counters.

The historical directory name is `apb_uart`. **No UART is implemented, and this is not a UVM class-based environment.** APB means Advanced Peripheral Bus; DUT means Design Under Test.

## Architecture

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
| `make faults` | Early-write injection at all three wait settings |
| `make dut-faults` | Four additional DUT faults at wait=1 |
| `make roles` | Task-level environment, request matching, and negative tests |
| `make protocol` | Legal trace and ten protocol violations |
| `make random` | Seeds, coverage closure, replay, and coverage-gap rejection |
| `make lint` / `make wave` | RTL lint / basic waveform generation |
| `make regression` | Complete project suite, stopping on any failed check |

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

See the [publication regression](reports/publication_regression.en.md) for the clean-build result. Earlier Chinese reports document historical versions and do not override current evidence.

## Reading Order

1. [Specification](spec.en.md), [verification plan](verification_plan.en.md), and [test matrix](test_matrix.en.md).
2. [RTL](rtl/apb_regs.sv), [basic testbench](tb/apb_regs_tb.sv), and [write-commit explanation](notes.en.md).
3. [Task-level testbench](tb/apb_roles_tb.sv), [request matching](docs/request_matching.en.md), and [protocol checks](docs/protocol_walkthrough.en.md).
4. [Random testing and coverage](docs/random_coverage.en.md), [DUT faults](bug_reports/dut_fault_matrix.en.md), and [end-to-end walkthrough](docs/final_walkthrough.en.md).

## Limitations

- Single-peripheral APB3 signal subset; no shared multi-peripheral bus, byte strobes, protection attributes, or UART.
- Task-level separation, not UVM; no class constraint solver, native covergroups, or concurrent protocol properties. Protocol checks use procedural immediate assertions and are compiled with `--assert`.
- Eleven explicit coverage bins are neither code coverage nor complete protocol coverage.
- Only wait settings 0/1/3 are tested; no arbitrary-parameter proof or per-transfer random wait duration.
- Mid-transfer reset is tested in the basic environment. The request-matching environment resets only between requests and has no explicit cancellation policy.
- Verilator runs do not establish complete four-state X/Z correctness. Between-edge glitches are outside the sampled checker scope.
- A write overwritten before readback is not fully checked by this bus-level model alone.
- All faults are deliberate injections, not defects discovered in commercial silicon or evidence of tapeout signoff.

This project uses AI-assisted development and grounds claims in runnable tests and explicit scope. Personal interview notes and machine-specific paths are excluded. Code retains explanatory Chinese comments, with bilingual core technical documentation.
