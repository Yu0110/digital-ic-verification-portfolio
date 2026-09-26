# Publication Regression

[简体中文](publication_regression.md) | **English**

Publication check: 2026-09-26. Built in an isolated publishing worktree from a project copy without existing build products, using Verilator 5.050 and the macOS C++ toolchain.

## Commands and Results

`make -C projects/apb_uart regression` exited 0:

| Check | Observed result |
|---|---|
| Basic directed | Waits 0/1/3: 20 transfers each; 100/161/281 checks pass |
| Early-write fault | `no setup write` detected at all three wait settings |
| Additional DUT faults | 4/4 designated checks detected at wait=1 |
| Task-level directed | 9 planned/matched/observed transfers per setting, no pending requests |
| Request-path faults | 5 classes x 3 settings: 15/15 detected |
| Observed read corruption | 3/3 detect actual 2B versus expected 2A |
| Protocol checker | Legal trace passes; 10/10 violations detected |
| Random and coverage | 9 runs x 219 transfers = 1,971, including 1,800 random; final 11/11 per run |
| Seed replay | Seed 11 at each wait setting: all 200 request lines identical |
| Coverage gaps | Three short runs match requests but hit only 6/11; all rejected by the gate |
| RTL lint | Pass |

The portfolio quick entry point `./scripts/run_all.sh` exited 0 with `ALL PORTFOLIO QUICK TESTS PASSED: 3/3`: arbiter, previously published FIFO version, and APB passed. The advanced FIFO/arbiter suites were not rerun in this publication check; quick regression is not represented as complete regression.

## Interpretation

- Final 11/11 includes directed prefix and closure traffic; it is not pure-random or code coverage.
- Replays and repeated quick checks do not add independent random scenarios.
- Faults are deliberate injections. Negative tests require a nonzero exit and the intended diagnostic.
- No new claim is made for four-state behavior, arbitrary waits, UART, multiple peripherals, or mid-request cancellation.
- Earlier 218-transfer runs are historical; the added tail readback makes current runs 219 transfers.
- Logs and compiled products remain under ignored `build/` directories and are not published.

See [scope and limitations](../docs/final_walkthrough.en.md).
