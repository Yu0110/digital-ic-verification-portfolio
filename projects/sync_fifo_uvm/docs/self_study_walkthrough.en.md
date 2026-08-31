# Synchronous FIFO Self-study and Execution Walkthrough

[简体中文](self_study_walkthrough.md) | **English**

This is the main learning entry point for the project. The goal is not to read every file line by line. Follow the verification workflow, read only the files required by the current stage, run that stage, and check your understanding before moving on.

FIFO = First In First Out.

RTL = Register Transfer Level.

DUT = Design Under Test.

UVM = Universal Verification Methodology.

SVA = SystemVerilog Assertions.

## 1. Outcome

After completing this walkthrough, you should be able to explain:

1. The synchronous FIFO interface and boundary rules.
2. How the RTL stores data and updates pointers and occupancy.
3. How the directed testbench predicts and checks behavior.
4. How interface, driver, monitor, reference model, and scoreboard cooperate.
5. The complete UVM path from sequence to DUT and back to coverage and checking.
6. The different roles of assertions, functional coverage, random regression, and fault injection.
7. How to reproduce all published verification evidence.

## 2. File Triage

### Read Carefully

```text
README.en.md
docs/specification.en.md
docs/architecture.en.md
rtl/sync_fifo.sv
tb/sync_fifo_tb.sv
tb/fifo_if.sv
tb/non_uvm/*.sv
core files under uvm/
docs/results.en.md
docs/bug_reports/*.en.md
```

### Understand the Purpose, but Do Not Read Line by Line Yet

```text
Makefile
scripts/run_directed.sh
scripts/run_layered.sh
scripts/setup_uvm.sh
scripts/uvm/*.sh
reports/*.md
```

### Skip During the First Review

```text
.deps/
build/
scripts/uvm_compat/malloc.h
*.out
*.log
*.vcd
```

`.deps/` contains third-party UVM source. `build/` contains generated artifacts. The compatibility header, binaries, logs, and waveforms are not part of the design review.

VCD = Value Change Dump.

## 3. Suggested Sessions

| Stage | Suggested time | Deliverable |
|---|---:|---|
| 0. Setup and project map | 20 minutes | Run the baseline regression |
| 1. Specification and RTL | 90 minutes | Explain every state transition |
| 2. Directed testbench | 90 minutes | Explain independent checking |
| 3. Layered non-UVM environment | 2 hours | Draw the verification data flow |
| 4. Core UVM components | 3 hours | Trace one transaction end to end |
| 5. Coverage and random regression | 90 minutes | Explain verification completeness |
| 6. Fault injection and review | 90 minutes | Present the project clearly |

## Stage 0: Setup and Project Map

Enter and open the project:

```bash
cd "/Users/mingyu/Desktop/毕业/芯片学习/digital-ic-verification-portfolio/projects/sync_fifo_uvm"
code .
make help
```

Run the baseline:

```bash
make directed
```

Expected completion marker:

```text
DIRECTED REGRESSION PASS: 5/5 parameter configurations passed.
```

Checkpoint:

- [ ] I can identify the project root.
- [ ] I understand that Makefile targets call shell scripts.
- [ ] The directed baseline passes.

## Stage 1: Specification and RTL

Read in this order:

```text
README.en.md
docs/specification.en.md
docs/architecture.en.md
rtl/sync_fifo.sv
```

Answer these questions from the specification:

1. When is a write accepted?
2. When is a read accepted?
3. Why does an empty simultaneous request accept only the write?
4. Why does a full simultaneous request accept only the read?
5. When may `rd_data` change?
6. Why is the memory array not reset element by element?

Find these sections in the RTL:

1. `DATA_WIDTH` and `DEPTH` parameters.
2. Pointer and occupancy widths.
3. Storage array.
4. Read and write acceptance conditions.
5. `empty`, `full`, and `data_count` generation.
6. Explicit pointer wrap.
7. Simultaneous-operation count handling.
8. Asynchronous reset.

Manually trace this depth-4 sequence:

```text
write A -> write B -> write C -> read A
-> write D -> read B -> read C -> read D
```

Track valid data, write pointer, read pointer, count, flags, and `rd_data` after every edge.

Run again:

```bash
make directed
```

The five tested configurations are:

```text
DATA_WIDTH=8  DEPTH=3
DATA_WIDTH=8  DEPTH=4
DATA_WIDTH=16 DEPTH=4
DATA_WIDTH=8  DEPTH=5
DATA_WIDTH=8  DEPTH=6
```

Checkpoint:

- [ ] I can explain empty, full, and middle-state rules.
- [ ] I can explain both pointers and occupancy.
- [ ] I can explain why depth 5 requires explicit wrap.
- [ ] I can separate combinational decisions from sequential state updates.

## Stage 2: Directed Self-checking Testbench

Read:

```text
tb/sync_fifo_tb.sv
scripts/run_directed.sh
```

Inspect in this order:

1. DUT instantiation and parameters.
2. Clock generation.
3. Expected state or queue.
4. Reset task.
5. Read/write task.
6. Comparison task.
7. Functional test groups.
8. Final error count and completion marker.

Run and inspect a log:

```bash
make directed
ls build/directed
less build/directed/sync_fifo_8x5.log
```

Press `q` to exit `less`.

Checkpoint:

- [ ] I know where stimulus and expected values come from.
- [ ] I understand why expected behavior must be independent of DUT internals.
- [ ] I understand drive and sample timing.
- [ ] I can define a self-checking testbench.

## Stage 3: Layered Non-UVM Verification

Read along the data flow:

```text
tb/fifo_if.sv
tb/non_uvm/fifo_transaction.sv
tb/non_uvm/fifo_generator.sv
tb/non_uvm/fifo_driver.sv
tb/non_uvm/fifo_monitor.sv
tb/non_uvm/fifo_reference_model.sv
tb/non_uvm/fifo_scoreboard.sv
tb/non_uvm/fifo_sva_checker.sv
tb/non_uvm/fifo_boundary_integration_tb.sv
```

Use this map:

```text
generator -> transaction -> driver -> interface -> DUT
                                              |
monitor <- interface <- DUT                   |
  |
  +-> scoreboard <-> reference model
  +-> coverage

SVA checker observes the interface in parallel.
```

Run:

```bash
make layered
```

Expected evidence:

```text
5/5 configurations
150 independent scoreboard comparisons
5 SVA properties with zero failures
```

Checkpoint:

- [ ] I can distinguish driver and monitor.
- [ ] I can distinguish reference model and scoreboard.
- [ ] I understand why the interface owns timing boundaries.
- [ ] I understand how temporal assertions differ from immediate comparisons.

## Stage 4: Core UVM Components

Prepare and smoke-test the toolchain:

```bash
make setup
make smoke
```

### Transaction Path to the DUT

Read:

```text
uvm/fifo_uvm_sequence_item.sv
uvm/fifo_uvm_basic_sequence.sv
uvm/fifo_uvm_coverage_sequence.sv
uvm/fifo_uvm_random_sequence.sv
uvm/fifo_uvm_sequencer.sv
uvm/fifo_uvm_driver.sv
```

Run one layer at a time:

```bash
./scripts/uvm/run_uvm_item_smoke.sh
./scripts/uvm/run_uvm_sequence_smoke.sh
./scripts/uvm/run_uvm_driver_smoke.sh
```

### Observation and Checking Path

Read:

```text
uvm/fifo_uvm_monitor.sv
uvm/fifo_uvm_reference_model.sv
uvm/fifo_uvm_scoreboard.sv
uvm/fifo_uvm_coverage.sv
```

Run:

```bash
./scripts/uvm/run_uvm_monitor_smoke.sh
./scripts/uvm/run_uvm_reference_model_smoke.sh
./scripts/uvm/run_uvm_scoreboard_smoke.sh
./scripts/uvm/run_uvm_coverage_smoke.sh
```

### Assembly and Topology

Read:

```text
uvm/fifo_uvm_agent.sv
uvm/fifo_uvm_environment.sv
uvm/fifo_uvm_pkg.sv
uvm/fifo_uvm_smoke_tb.sv
uvm/fifo_uvm_environment_test.sv
```

Run active and passive agents:

```bash
./scripts/uvm/run_uvm_environment_smoke.sh
./scripts/uvm/run_uvm_passive_agent_smoke.sh
```

Checkpoint:

- [ ] I can trace sequence -> sequencer -> driver -> DUT.
- [ ] I can trace DUT -> monitor -> scoreboard and coverage.
- [ ] I understand active and passive agent modes.
- [ ] I understand virtual interface and analysis port.

## Stage 5: Coverage and Random Regression

Run the exact 15-group order:

```bash
./scripts/uvm/run_uvm_smoke.sh
./scripts/uvm/run_uvm_item_smoke.sh
./scripts/uvm/run_uvm_sequence_smoke.sh
./scripts/uvm/run_uvm_driver_smoke.sh
./scripts/uvm/run_uvm_monitor_smoke.sh
./scripts/uvm/run_uvm_reference_model_smoke.sh
./scripts/uvm/run_uvm_scoreboard_smoke.sh
./scripts/uvm/run_uvm_scoreboard_fault.sh
./scripts/uvm/run_uvm_environment_smoke.sh
./scripts/uvm/run_uvm_passive_agent_smoke.sh
./scripts/uvm/run_uvm_environment_topology_fault.sh
./scripts/uvm/run_uvm_coverage_smoke.sh
./scripts/uvm/run_uvm_coverage_fault.sh
./scripts/uvm/run_uvm_random_coverage_gate_fault.sh
./scripts/uvm/run_uvm_random_regression.sh
```

Then run the aggregate target:

```bash
make regression
```

Expected summary:

```text
11 positive groups
4 expected-negative groups
20 fixed seeds
200 random transactions per seed
4,080 scoreboard comparisons
```

An expected-negative PASS means that the environment detected the intentional fault with the exact expected severity and count.

Review:

```text
docs/test_matrix.en.md
docs/verification_plan.en.md
docs/results.en.md
reports/uvm_regression_summary.md
```

Checkpoint:

- [ ] I can distinguish code coverage from functional coverage.
- [ ] I understand coverpoint, bin, and cross.
- [ ] I understand deterministic seed replay.
- [ ] I understand expected-negative tests.

## Stage 6: DUT Fault Injection and Release Verification

Read:

```text
docs/bug_reports/BUG-INJECT-001_count_update.en.md
docs/bug_reports/BUG-INJECT-002_pointer_wrap_root_cause.en.md
docs/bug_reports/BUG-INJECT-003_full_write_overwrite.en.md
```

Run each mutation:

```bash
./scripts/faults/run_count_update.sh
./scripts/faults/run_pointer_wrap.sh
./scripts/faults/run_full_write_overwrite.sh
```

The inner faulty simulations must fail. The outer scripts pass only after confirming the expected checker signature.

Run all faults and the complete release suite:

```bash
make faults
make verify
```

Expected final marker:

```text
FULL VERIFICATION PASS
```

Review the generated evidence:

```text
reports/full_verification_summary.md
reports/uvm_regression_summary.md
```

Final checkpoint:

- [ ] All three DUT mutations are detected.
- [ ] I can explain the different roles of scoreboard, SVA, and coverage.
- [ ] `make verify` passes.
- [ ] I can present the published metrics without reading the README.

## Final Command Sheet

```bash
cd "/Users/mingyu/Desktop/毕业/芯片学习/digital-ic-verification-portfolio/projects/sync_fifo_uvm"
code .
make help
make setup
make directed
make layered
make smoke
make regression
make faults
make verify
```

Follow one rule: read the small set of files for the current stage, run that stage, and complete its checkpoint before opening the next group of files.
