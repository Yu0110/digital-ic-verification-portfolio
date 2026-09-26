# Verification Plan

[简体中文](verification_plan.md) | **English**

The following applies to the original APB register baseline.

- Maintain an independent expected DATA value, updated only on successful completed legal writes.
- Check read data, error response, wait duration, and post-completion register contents.
- In the basic testbench, inspect the internal register during SETUP and waits to catch early updates. This white-box check depends on implementation signal names.
- Require 20 completed transfers in each basic run, 9 in each task-level directed run, and 219 in each random-coverage run. Abort on failures or timeout.
- Test wait settings 0/1/3. Positive tests must pass; negative tests must fail with the specified diagnostic.
- Separate driver, monitor, request matcher, and scoreboard responsibilities through tasks. This is not a class/UVM environment.
- Independently test the procedural protocol checker with legal behavior and ten violations before using it in the task-level environment. Enable assertions with `--assert`.
- Match completed transfers against an independent planned-request queue, including address, direction, write data, missing requests, and extra transfers. Test five driver-path faults at each wait setting.
- Run 3 seeds x 3 wait settings, explicit 11-bin functional coverage, directed closure, same-seed replay, and deliberate coverage-gap rejection.
- Inject five DUT faults: early write, missing error response, read-only protection failure, wrong reset value, and corrupt read data. Keep these distinct from driver faults and observation corruption.
- Run all checks through `make regression`. The request-matching environment does not yet implement mid-request reset cancellation.

## UART Extension

- Sample 8N1 TX bits and independently compare start, LSB-first data, stop, and idle-high levels.
- Exercise RX through both TX-to-RX loopback and independent serial stimulus; check RXDATA readback and valid-bit clearing.
- Check busy TXDATA rejection, retention of unread data on overrun, invalid stop bit, illegal accesses, and reset during transmission.
- Run 8/16 clocks per bit x 0/1/3 APB wait cycles. `make uart-smoke` runs one configuration; `make regression` runs all six.
- UART constrained-random stimulus, coverage closure, and fault injection are not claimed. Original APB coverage does not transfer to the UART extension.
