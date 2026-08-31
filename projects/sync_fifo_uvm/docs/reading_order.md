# 代码阅读指南

**简体中文** | [English](reading_order.en.md)

第一次完整学习，请使用 [同步 FIFO 项目从头到尾自学与运行计划](self_study_walkthrough.md)。本文件用于快速复查。

## 设计

1. [设计规格](specification.md)
2. [RTL 实现](../rtl/sync_fifo.sv)
3. [定向自检式 testbench](../tb/sync_fifo_tb.sv)

## 验证基础设施

1. [Interface 接口](../tb/fifo_if.sv)
2. [Assertions 断言](../tb/non_uvm/fifo_sva_checker.sv)
3. [Sequence item 事务对象](../uvm/fifo_uvm_sequence_item.sv)
4. [Driver 驱动器](../uvm/fifo_uvm_driver.sv)
5. [Monitor 监视器](../uvm/fifo_uvm_monitor.sv)
6. [Reference model 参考模型](../uvm/fifo_uvm_reference_model.sv)
7. [Scoreboard 记分板](../uvm/fifo_uvm_scoreboard.sv)
8. [Coverage collector 覆盖率收集器](../uvm/fifo_uvm_coverage.sv)
9. [Agent 代理](../uvm/fifo_uvm_agent.sv)
10. [Environment 验证环境](../uvm/fifo_uvm_environment.sv)
11. [UVM 仿真顶层](../uvm/fifo_uvm_smoke_tb.sv)

## 回归入口

- `make directed`：运行参数化定向测试；
- `make layered`：运行分层边界测试和断言；
- `make regression`：运行完整 UVM 回归；
- `make faults`：运行受控设计故障注入；
- `make verify`：运行完整项目验证。

RTL = Register Transfer Level，寄存器传输级。

UVM = Universal Verification Methodology，通用验证方法学。
