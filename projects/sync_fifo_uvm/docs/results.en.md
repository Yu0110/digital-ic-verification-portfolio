# Verification Results

[简体中文](results.md) | **English**

## Parameterized Directed Regression

| Configuration | Checks | Errors |
|---|---:|---:|
| `DATA_WIDTH=8, DEPTH=3` | 91 | 0 |
| `DATA_WIDTH=8, DEPTH=4` | 103 | 0 |
| `DATA_WIDTH=16, DEPTH=4` | 103 | 0 |
| `DATA_WIDTH=8, DEPTH=5` | 115 | 0 |
| `DATA_WIDTH=8, DEPTH=6` | 127 | 0 |
| Total | 539 | 0 |

The layered regression completed 150 independent scoreboard comparisons. Every configuration exercised all five temporal assertions with zero failures.

## Directed UVM Coverage

- Transactions compared: 16/16
- Read hits for empty/middle/full states: `2/4/1`
- Write hits for empty/middle/full states: `1/4/1`
- Simultaneous-operation hits for empty/middle/full states: `1/1/1`
- Post-operation count hits for `0..4`: `4/4/2/3/3`
- Functional coverage: 100%
- Assertion failures: 0

## Constrained-Random Regression

- Fixed seeds: 20
- Random transactions per seed: 200
- Drain transactions per seed: 4
- Total comparisons: 4,080
- Random operation distribution: 1,558 reads, 1,621 writes, 821 simultaneous operations
- Coverage per seed: 100%
- Seed `20260801` replay digest: `4fe9e16e7caf8a3d`

## UVM Regression

- Positive groups: 11/11
- Expected-negative groups: 4/4
- Total: 15/15

An expected-negative pass means the environment detected the injected fault with the expected severity and count.

## Fault Injection

| Mutation | Checker | Result |
|---|---|---|
| Incorrect simultaneous count update | Directed state check | Detected |
| Invalid non-power-of-two pointer wrap | Reference model and scoreboard | Detected |
| Full-write data overwrite | Drain-and-compare sequence | Detected |
