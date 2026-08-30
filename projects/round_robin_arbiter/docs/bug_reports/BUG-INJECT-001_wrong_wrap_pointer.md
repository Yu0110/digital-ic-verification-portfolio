# Bug 001: Requester 3 Wrap Pointer Error

## 摘要

请求者 3 获授权后，下一轮起点错误地设置为请求者 1，而不是回卷到请求者 0。

bug = 软件或硬件设计中的错误。

## 注入位置

在 `priority_ptr=2`、请求者 3 为第一个有效请求的分支中：

```systemverilog
grant             = 4'b1000;
priority_ptr_next = 2'b01;  // 错误，应为 2'b00
```

可复现补丁见 [`BUG-INJECT-001_wrong_wrap_pointer.patch`](BUG-INJECT-001_wrong_wrap_pointer.patch)，执行 `make faults` 可自动完成临时变异、仿真和预期失败检查。

## 预期行为

授权请求者 3 后应回卷到请求者 0，因此下一指针必须为 `2'b00`。

## 实际失败

在起点 2 授权请求者 3 后，测试平台使用 `req=1111` 探测下一状态。正确起点 0 应授权 `0001`，变异设计从错误起点 1 开始并输出 `0010`，黑盒记分板报告：

```text
ERROR [next-state black-box probe: grant mismatch]
req=1111 model_ptr=0 expected=0001 actual=0010
```

完整回归会同时报告授权不匹配和公平性窗口缺失，并以非零状态结束。故障注入脚本确认失败标记存在后，将这个预期失败判定为故障检出成功。

## 根因

回卷状态编码填写错误。本周期授权仍然正确，所以只检查当前 `grant` 会漏掉该错误；必须在后续周期从接口检查状态传播。

## 修复

```systemverilog
priority_ptr_next = 2'b00;
```

## 预防措施

- 在测试矩阵中保留请求者 3 到请求者 0 的回卷场景；
- 使用黑盒下一状态探针检查状态推进；
- 把故障补丁与预期失败脚本纳入发布回归。

## 结论

该实验说明独立参考模型和黑盒状态探针能够捕获内部状态更新错误，同时避免测试平台依赖 DUT 私有信号。
