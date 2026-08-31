# BUG-INJECT-002：非 2 的整数次幂深度指针回卷错误

**简体中文** | [English](BUG-INJECT-002_pointer_wrap_root_cause.en.md)

## 摘要

当 `DEPTH=5` 时，三位指针可以表示地址 0 到 7，但只有 0 到 4 合法。注入的故障让指针从地址 4 增加到 5，而不是回卷到 0。

## 复现方法

```bash
./scripts/faults/run_pointer_wrap.sh
```

脚本使用 `FIFO_INJECT_BUG_002` 编译 `rtl/sync_fifo.sv`，并在 `DATA_WIDTH=8, DEPTH=5` 的配置下运行 33 笔边界事务。

## 失败特征

第一次不匹配出现在第 14 次比较。参考模型预期得到 `8'h44`，错误设计却返回 `8'h00`。

```text
SCOREBOARD ERROR comparison=14
ACTUAL_TX   rd_data=0x0  count=1 empty=0 full=0
EXPECTED_TX rd_data=0x44 count=1 empty=0 full=0

BUG-INJECT-002 PASS: scoreboard detected the intentional DEPTH=5 pointer-wrap defect.
```

错误运行会产生 10 次数据不匹配。由于地址生成和数据量跟踪互相独立，数量和状态标志仍有可能保持正确。

## 根因

只有 FIFO 深度正好等于指针全部编码范围时，二进制自然溢出才是正确回卷。实现必须在最后一个合法地址处显式回卷：

```systemverilog
if (current_ptr == LAST_ADDR) begin
    next_ptr = '0;
end else begin
    next_ptr = current_ptr + 1'b1;
end
```

## 防回归覆盖

- 深度 3、5 和 6；
- 多次完整指针回卷；
- 完整的数据顺序比较。

FIFO = First In First Out，先进先出队列。
