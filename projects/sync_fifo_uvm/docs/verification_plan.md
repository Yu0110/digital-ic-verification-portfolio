# Verification Plan

## Objectives

1. Preserve write order across reads.
2. Enforce empty-read, full-write, and simultaneous-operation rules.
3. Keep `data_count`, `empty`, and `full` consistent.
4. Wrap pointers correctly for power-of-two and non-power-of-two depths.
5. Apply asynchronous reset independently of the clock.
6. Detect controlled design and verification-environment faults.

## Risk Matrix

| Risk | Detection strategy |
|---|---|
| Data reordering or corruption | Independent queue model and scoreboard |
| Full write overwrites valid data | Reject write, then drain and compare all entries |
| Empty read advances state | Repeated empty reads followed by write/read |
| Pointer enters an invalid address | Multi-wrap tests with `DEPTH=3, 5, 6` |
| Simultaneous operation updates count incorrectly | Directed boundary cases and assertions |
| Reference model copies design behavior | Independent parameterized model contract test |
| Monitor drops or duplicates transactions | End-to-end transaction counters |
| Coverage misses planned behavior | Functional coverage closure gate |
| Test exits before completion | Unique completion markers and watchdogs |

## Verification Layers

- Parameterized directed self-checking tests.
- Layered non-UVM boundary tests.
- Five temporal assertions.
- UVM component and topology checks.
- Directed coverage closure.
- Fixed-seed constrained-random regression and replay.
- Design and verification-environment fault injection.

## Exit Criteria

- 5/5 parameterized directed configurations pass.
- 5/5 layered configurations pass with all assertions exercised.
- Directed UVM coverage reaches 100%.
- 20 fixed random seeds pass and the first seed replays identically.
- 11 positive and 4 expected-negative UVM groups pass their exact criteria.
- All three controlled design faults are detected.
