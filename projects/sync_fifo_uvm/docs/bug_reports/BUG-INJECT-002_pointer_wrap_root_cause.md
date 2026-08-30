# BUG-INJECT-002: Non-Power-of-Two Pointer Wrap

## Summary

For `DEPTH=5`, a three-bit pointer can represent addresses zero through seven, but only zero through four are legal. The injected defect increments from address four to five instead of wrapping to zero.

## Reproduction

```bash
./scripts/faults/run_pointer_wrap.sh
```

The script compiles `rtl/sync_fifo.sv` with `FIFO_INJECT_BUG_002` and runs 33 boundary transactions at `DATA_WIDTH=8, DEPTH=5`.

## Failure Signature

The first mismatch occurs at comparison 14. The reference model expects `8'h44` while the faulty design returns `8'h00`.

```text
SCOREBOARD ERROR comparison=14
ACTUAL_TX   rd_data=0x0  count=1 empty=0 full=0
EXPECTED_TX rd_data=0x44 count=1 empty=0 full=0

BUG-INJECT-002 PASS: scoreboard detected the intentional DEPTH=5 pointer-wrap defect.
```

The faulty run produces 10 data mismatches. Count and status flags can remain correct because address generation and occupancy tracking are independent.

## Root Cause

Natural binary overflow is only correct when the FIFO depth matches the pointer's full encoding range. The implementation must wrap at the last legal address:

```systemverilog
if (current_ptr == LAST_ADDR) begin
    next_ptr = '0;
end else begin
    next_ptr = current_ptr + 1'b1;
end
```

## Regression Coverage

- Depths 3, 5, and 6
- Multiple complete pointer wraps
- Full data-order comparison
- Correct-design parameter regression: 5/5
- Fault reproduction with a stable first mismatch
