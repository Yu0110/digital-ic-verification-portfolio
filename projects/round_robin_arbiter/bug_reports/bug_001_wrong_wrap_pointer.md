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

可复现补丁见 [`bug_001_wrong_wrap_pointer.patch`](bug_001_wrong_wrap_pointer.patch)。

## 预期行为

授权请求者 3 后应回卷到请求者 0，因此下一指针必须为 `2'b00`。

## 实际失败

稀疏请求测试从指针 2、`req=1011` 开始。授权 `1000` 正确，但上升沿后的指针错误，testbench 首先报告：

```text
FAIL 14 POINTER: ptr=1, expected_next_ptr=0
```

错误状态随后改变后续搜索起点，引发连续失败；重新复位后状态恢复。

## 根因

回卷状态编码填写错误。授权数据路径本周期仍正确，所以只检查 `grant` 的 testbench 可能漏掉该错误；必须同时检查下一状态。

## 修复

```systemverilog
priority_ptr_next = 2'b00;
```

## 预防措施

- 在测试矩阵中保留请求者 3 到请求者 0 的回卷场景；
- 同时检查组合输出和上升沿后的状态；
- 后续加入断言，约束请求者 3 服务完成后的下一轮起点。

## 结论

该实验说明自检式 testbench 能捕获状态更新错误，而不仅是当前周期的授权错误。
