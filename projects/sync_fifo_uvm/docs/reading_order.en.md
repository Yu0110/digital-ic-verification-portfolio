# Code Guide

[简体中文](reading_order.md) | **English**

For the complete study path, commands, and checkpoints, see the [synchronous FIFO self-study walkthrough](self_study_walkthrough.en.md).

## Design

1. [Specification](specification.en.md)
2. [RTL implementation](../rtl/sync_fifo.sv)
3. [Directed self-checking testbench](../tb/sync_fifo_tb.sv)

## Verification Infrastructure

1. [Interface](../tb/fifo_if.sv)
2. [Assertions](../tb/non_uvm/fifo_sva_checker.sv)
3. [Sequence item](../uvm/fifo_uvm_sequence_item.sv)
4. [Driver](../uvm/fifo_uvm_driver.sv)
5. [Monitor](../uvm/fifo_uvm_monitor.sv)
6. [Reference model](../uvm/fifo_uvm_reference_model.sv)
7. [Scoreboard](../uvm/fifo_uvm_scoreboard.sv)
8. [Coverage collector](../uvm/fifo_uvm_coverage.sv)
9. [Agent](../uvm/fifo_uvm_agent.sv)
10. [Environment](../uvm/fifo_uvm_environment.sv)
11. [UVM top](../uvm/fifo_uvm_smoke_tb.sv)

## Regression Entry Points

- `make directed`: parameterized directed tests
- `make layered`: layered boundary tests and assertions
- `make regression`: complete UVM regression
- `make faults`: controlled design mutations
- `make verify`: complete project verification
