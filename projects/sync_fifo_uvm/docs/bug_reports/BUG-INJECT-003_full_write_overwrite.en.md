# BUG-INJECT-003: Data Overwrite on Rejected Full Write

[简体中文](BUG-INJECT-003_full_write_overwrite.md) | **English**

## Summary

A full FIFO must reject a write without changing memory. The injected defect writes new data at `wr_ptr` while leaving pointers, count, and flags unchanged. The corruption becomes visible only on a later read.

## Reproduction

```bash
./scripts/faults/run_full_write_overwrite.sh
```

The script compiles `rtl/sync_fifo.sv` with `FIFO_INJECT_BUG_003` and runs the non-power-of-two boundary sequence at `DEPTH=5`.

## Failure Signature

The FIFO is filled with `40, 41, 42, 43, 44`. A rejected write of `EE` overwrites `40`. The write cycle appears correct because `data_count` and `full` hold; the next read exposes the corruption.

```text
SCOREBOARD ERROR comparison=10
ACTUAL_TX   rd_data=0xee count=4 empty=0 full=0
EXPECTED_TX rd_data=0x40 count=4 empty=0 full=0

BUG-INJECT-003 PASS: scoreboard detected the intentional full-write data overwrite.
```

## Root Cause

The storage array was updated when `write_accept` was false. Memory and the write pointer must change only in the accepted-write branch:

```systemverilog
if (write_accept) begin
    memory[wr_ptr] <= wr_data;
    wr_ptr         <= next_ptr(wr_ptr);
end
```

## Regression Coverage

- Fill to full
- Rejected write
- Complete drain and data-order comparison
- Count and flag checks
- Stable single-mismatch fault signature
