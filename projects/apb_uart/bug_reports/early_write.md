# 人为故障：准备阶段提前写入

这是检查器验证用的主动注入，不是真实产品缺陷。

- 复现：`make faults`，启用 `INJECT_EARLY_WRITE=1`。
- 错误：准备阶段 `psel=1, penable=0` 就修改 DATA。
- 预期：传输尚未完成，DATA 应保留原值。
- 现象：首次写 2A 时报告 `CHECK_FAIL no setup write`；等待 0、1、3 均检出。
- 根因：把准备请求误当成完成写入。
- 正确逻辑：上升沿满足 `psel && penable && pready && pwrite && !bad_access` 才写入。
- 复测：默认关闭注入，60 笔事务、542 次检查通过。

使用内部寄存器白盒检查发现提前变化；只检查最终读回值可能漏掉这个错误。
