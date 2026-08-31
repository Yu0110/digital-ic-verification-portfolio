# Test Matrix

[简体中文](test_matrix.md) | **English**

## Functional Scenarios

| Scenario | Checks |
|---|---|
| Asynchronous reset | Pointers, count, output data, and flags |
| Single write/read | Count transition and returned data |
| Ordered stream | First-in-first-out ordering |
| Repeated empty read | State and `rd_data` hold |
| Fill and drain | Every count level and boundary flag |
| Rejected full write | Existing data remains intact |
| Simultaneous read/write | Returned head, appended tail, count hold |
| Simultaneous request while empty | Write accepted, read rejected |
| Simultaneous request while full | Read accepted, write rejected |
| Multiple pointer wraps | Legal addressing and ordering |

## Parameter Matrix

| Data width | Depth | Purpose |
|---:|---:|---|
| 8 | 3 | Small non-power-of-two depth |
| 8 | 4 | Default configuration |
| 16 | 4 | Data-width parameterization |
| 8 | 5 | Pointer-width boundary |
| 8 | 6 | Larger non-power-of-two depth |

## UVM Regression

| Group | Test | Expected result |
|---:|---|---|
| 1 | Minimal toolchain smoke | Pass |
| 2 | Sequence-item contract | Pass |
| 3 | Sequence/sequencer handshake | Pass |
| 4 | Driver and DUT integration | Pass |
| 5 | Monitor publication | Pass |
| 6 | Reference-model contract | Pass |
| 7 | Scoreboard comparison | Pass |
| 8 | Scoreboard field mutations | Six expected errors |
| 9 | Active agent and environment | Pass |
| 10 | Passive agent | Pass |
| 11 | Missing environment subscriber | One expected fatal |
| 12 | Directed coverage closure | 100% |
| 13 | Invalid coverage samples | Four expected errors |
| 14 | Random coverage gate | One expected fatal |
| 15 | 20-seed random regression and replay | Pass |

## Assertions

| Property | Expected behavior |
|---|---|
| Mid-state simultaneous read/write | Count holds |
| Empty read | Count, empty flag, and read data hold |
| Full write | Count, full flag, and read data hold |
| Empty-state simultaneous request | Count becomes one |
| Full-state simultaneous request | Count becomes `DEPTH - 1` |

## Design Mutations

| Identifier | Mutation | Required detection |
|---|---|---|
| BUG-INJECT-001 | Increment count on simultaneous read/write | Count mismatch |
| BUG-INJECT-002 | Allow pointer to exceed `DEPTH - 1` | Data mismatch |
| BUG-INJECT-003 | Overwrite data on rejected full write | Subsequent read mismatch |
