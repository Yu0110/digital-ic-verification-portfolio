# Synchronous FIFO Specification

[简体中文](specification.md) | **English**

## Parameters

| Parameter | Constraint | Description |
|---|---:|---|
| `DATA_WIDTH` | `> 0` | Width of each stored item |
| `DEPTH` | `>= 2` | Number of storage entries |

Pointer width is derived from `DEPTH`. Count width is derived from `DEPTH + 1` so that `data_count` can represent every value from zero through full depth.

## Interface

| Signal | Direction | Width | Description |
|---|---|---:|---|
| `clk` | input | 1 | Rising-edge clock |
| `rst_n` | input | 1 | Active-low asynchronous reset |
| `wr_en` | input | 1 | Write request |
| `wr_data` | input | `DATA_WIDTH` | Write data |
| `rd_en` | input | 1 | Read request |
| `rd_data` | output | `DATA_WIDTH` | Registered read data |
| `empty` | output | 1 | Asserted when `data_count == 0` |
| `full` | output | 1 | Asserted when `data_count == DEPTH` |
| `data_count` | output | `clog2(DEPTH + 1)` | Number of valid entries |

## Operation Rules

Requests are evaluated from the state immediately before each rising clock edge.

| State and request | Accepted operation | Result |
|---|---|---|
| `wr_en && !full` | Write | Store at `wr_ptr` and advance the write pointer |
| `rd_en && !empty` | Read | Register data at `rd_ptr` and advance the read pointer |
| Both accepted | Read and write | Preserve `data_count` |
| Empty with both requests | Write only | Increment `data_count` |
| Full with both requests | Read only | Decrement `data_count` |
| Empty read | None | Preserve pointers, count, and `rd_data` |
| Full write | None | Preserve memory, pointers, count, and `rd_data` |

Pointers wrap explicitly at `DEPTH - 1`. This is required when `DEPTH` is not a power of two.

## Reset

When `rst_n` is low:

- `wr_ptr`, `rd_ptr`, `data_count`, and `rd_data` are cleared.
- `empty` is asserted and `full` is deasserted.
- Memory contents are not cleared; `data_count == 0` marks all entries invalid.

Reset assertion does not depend on a clock edge. The testbench releases reset away from the active clock edge.
