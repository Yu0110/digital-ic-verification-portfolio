# BUG-INJECT-003：满状态拒绝写入后数据被覆盖

**简体中文** | [English](BUG-INJECT-003_full_write_overwrite.en.md)

## 摘要

FIFO 已满时必须拒绝写入，并且不能修改存储阵列。注入的故障在保持指针、数量和状态标志不变的同时，仍然把新数据写入 `wr_ptr`。数据损坏要到后续读取时才会暴露。

## 复现方法

```bash
./scripts/faults/run_full_write_overwrite.sh
```

脚本使用 `FIFO_INJECT_BUG_003` 编译 `rtl/sync_fifo.sv`，并在 `DEPTH=5` 下运行非 2 的整数次幂边界序列。

## 失败特征

FIFO 先被 `40, 41, 42, 43, 44` 填满。随后本应被拒绝的 `EE` 覆盖了 `40`。写入周期表面上仍然正确，因为 `data_count` 和 `full` 保持不变；下一次读取才暴露数据损坏。

```text
SCOREBOARD ERROR comparison=10
ACTUAL_TX   rd_data=0xee count=4 empty=0 full=0
EXPECTED_TX rd_data=0x40 count=4 empty=0 full=0

BUG-INJECT-003 PASS: scoreboard detected the intentional full-write data overwrite.
```

## 根因

当 `write_accept` 为假时，存储阵列仍被错误更新。存储阵列和写指针只能在写入被接受的分支中改变：

```systemverilog
if (write_accept) begin
    memory[wr_ptr] <= wr_data;
    wr_ptr         <= next_ptr(wr_ptr);
end
```

## 防回归覆盖

- 填满 FIFO；
- 拒绝满状态写入；
- 完整排空并比较数据顺序；
- 检查数量和状态标志；
- 保持稳定、单一的不匹配特征。

FIFO = First In First Out，先进先出队列。
