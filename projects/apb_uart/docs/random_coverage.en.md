# Random Testing and Functional Coverage

[简体中文](random_coverage.md) | **English**

Run `make random` or the complete `make regression` suite. Wait settings 0/1/3 each run seeds 11/29/47. Each run includes a directed prefix, 200 random requests, ten directed closure/readback requests, and post-reset reading: 219 completed transfers in total.

## Stimulus and Replay

Random choices cover read/write direction, DATA/ID/other-aligned/misaligned address categories, and zero/all-one/random write values. All requests still use legal APB timing: an invalid address is a functional error access, not a protocol timing violation.

Wait duration is fixed per run and reset timing is not randomized. At each wait setting, seed 11 is replayed and all 200 `RANDOM_REQ` lines are compared. Reproducibility is claimed only for the same code and tool environment, not across simulator versions.

## Eleven Bins

The first eight bins cross read/write with four address categories: DATA, ID, other aligned, and misaligned. Three more bins classify legal DATA writes as zero, all ones, or other values.

Coverage is sampled only after completion, request matching, and functional checks. Correctly rejected invalid accesses count toward their error-access bins. Each bin records hits and needs at least one hit to be covered.

This is explicit array-counter functional coverage, not native covergroups or code coverage. A final 11/11 says only that these eleven defined bins were hit.

## Directed Closure

Ten post-random requests fill address/direction bins and write-data categories, including an all-one readback before reset. That readback was added during audit so reset would not hide the final write result. The directed prefix already supplies an other-value DATA write.

`COVERAGE_BEFORE_CLOSURE` includes both the directed prefix and random segment; it is not pure-random coverage. Final 11/11 includes directed closure contributions.

## Checking the Coverage Gate

The additional `+coverage +no_close +random_count=0` run completes nine correctly matched transfers but hits only 6/11 bins. It must fail with `COVERAGE_GAP`, showing that correct observed results do not guarantee sufficient scenario coverage.

## Limits

No complete reset/wait/address cross, random mid-transfer reset, exhaustive addresses/data, pipelined concurrency, or UART is claimed. Basic directed and dedicated protocol tests remain necessary. Writes overwritten before readback are not all independently proven correct by the bus-level model.
