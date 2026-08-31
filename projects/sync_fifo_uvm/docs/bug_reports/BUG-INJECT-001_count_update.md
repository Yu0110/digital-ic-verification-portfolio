# BUG-INJECT-001：同时读写时数据量更新错误

**简体中文** | [English](BUG-INJECT-001_count_update.en.md)

## 摘要

当 FIFO 处于非空、非满状态，并且读取和写入同时被接受时，一份数据离开、一份数据进入，因此 `data_count` 必须保持不变。注入的故障却错误地把数量加 1。

## 复现方法

```bash
./scripts/faults/run_count_update.sh
```

脚本使用 `FIFO_INJECT_BUG_001` 编译 `rtl/sync_fifo.sv`。内部仿真必须因为预期的数量不匹配而失败；外层脚本确认失败原因正确后才判定故障测试通过。

## 预期行为与故障行为

初始队列：`A, B`

操作：读取 `A`，同时写入 `C`

- 预期队列：`B, C`，数量为 `2`；
- 故障数量：`3`。

```text
ERROR read A and write C: data_count actual=3 expected=2
BUG-INJECT-001 PASS: directed testbench detected the intentional count-update defect.
```

## 根因

错误分支把同时接受读取和写入当成了只写操作。正确的数量更新逻辑是：

```systemverilog
case ({write_accept, read_accept})
    2'b10:   data_count <= data_count + 1'b1;
    2'b01:   data_count <= data_count - 1'b1;
    default: data_count <= data_count;
endcase
```

## 防回归覆盖

- 空、中间、满状态下的同时请求；
- 直接检查数量和状态标志；
- 使用独立队列进行结果比较。

FIFO = First In First Out，先进先出队列。
