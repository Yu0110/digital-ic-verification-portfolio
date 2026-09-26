# Turning APB Rules into Code

[简体中文](notes.md) | **English**

A request being present does not mean it has committed. Only a completed, legal write changes DATA:

```systemverilog
if (psel && penable && pready && pwrite && !bad_access)
    data_reg <= pwdata;
```

This executes inside a rising-edge `always_ff`, with reset taking priority. The first three terms mean completion; the last two require a legal write.

- RTL implements storage and responses. The testbench supplies requests, predicts results, and checks them.
- `expected` is derived from the specification, never copied from the DUT register.
- Internal register checks are additional white-box checks of update timing.
- PREADY alone does not imply completion; selection, ACCESS, and the clock edge also matter.
- PSLVERR indicates an error on a completed transfer, not a request to keep waiting.
- Holding a request during wait cycles does not authorize committing the same write on each cycle.
- Passing tests establishes behavior in tested scenarios, not correctness for every possible input.

Follow `transfer(1, 0, 32'h2a)` from SETUP to completion in the basic testbench to connect these rules to the code.
