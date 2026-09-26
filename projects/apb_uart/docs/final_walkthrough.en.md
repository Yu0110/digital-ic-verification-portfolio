# End-to-End Walkthrough

[简体中文](final_walkthrough.md) | **English**

This is single-peripheral APB3 register verification, not UART or a complete UVM verification IP. The directory retains its original planning name.

## Follow One Write and Read

1. The specification defines 00 as read/write and 04 as read-only; storage must not update early.
2. `submit` stores the plan; `drive` drives bus signals.
3. The protocol checker checks phase transitions and request stability at clock edges.
4. The monitor samples only completed transfers.
5. Request matching checks that the executed operation matches the plan.
6. The scoreboard predicts legality and response, updates expected state, or compares read data.
7. Successful checks feed functional coverage counters.
8. Final checks reject pending requests, wrong counts, and insufficient coverage.

Start with `submit(1, 0, 32'h2a)` and the following read in `tb/apb_roles_tb.sv`.

## Audit Improvements

- Add readback after the final all-one closure write, before reset. Current runs have 219 transfers; earlier 218-transfer reports are historical.
- Print compilation progress and display the compile log on failure.
- Exercise five injected DUT fault classes covering commit timing, errors, read-only protection, reset, and read data.

## Boundaries

- 11/11 covers eleven declared bins, not complete protocol or code coverage.
- Wait settings are fixed to 0/1/3; no arbitrary-parameter proof.
- Basic tests cover mid-transfer reset; the request queue resets only between transfers and lacks cancellation handling.
- Protocol checks use historical samples and immediate assertions, not concurrent properties.
- Verilator evidence is not comprehensive X/Z verification. Between-edge glitches are not sampled.
- A random write overwritten before readback may escape the bus-level model; basic white-box tests and tail readback add checks, not a formal proof.
- DUT faults, driver faults, and observation corruption are all deliberately injected.

Run `make regression`, follow a completed write/read, then inspect a designated negative-test diagnostic. Retest with injection disabled. See the [publication regression](../reports/publication_regression.en.md).
