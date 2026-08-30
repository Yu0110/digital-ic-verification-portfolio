# BUG-INJECT-001: Incorrect Simultaneous Count Update

## Summary

When a read and write are both accepted in a non-empty, non-full state, one item leaves and one item enters. `data_count` must hold. The injected defect increments the count instead.

## Reproduction

```bash
./scripts/faults/run_count_update.sh
```

The script compiles `rtl/sync_fifo.sv` with `FIFO_INJECT_BUG_001`. The inner simulation must fail with the expected count mismatch; the outer script passes only after matching that failure.

## Expected and Observed Behavior

Initial queue: `A, B`

Operation: read `A` and write `C`

- Expected queue: `B, C`, count `2`
- Faulty count: `3`

```text
ERROR read A and write C: data_count actual=3 expected=2
BUG-INJECT-001 PASS: directed testbench detected the intentional count-update defect.
```

## Root Cause

The faulty branch treats simultaneous acceptance as a write-only operation. The correct count update is:

```systemverilog
case ({write_accept, read_accept})
    2'b10:   data_count <= data_count + 1'b1;
    2'b01:   data_count <= data_count - 1'b1;
    default: data_count <= data_count;
endcase
```

## Regression Coverage

- Simultaneous requests in empty, middle, and full states
- Direct count and flag checks
- Independent queue comparison
- Temporal assertion for count hold
