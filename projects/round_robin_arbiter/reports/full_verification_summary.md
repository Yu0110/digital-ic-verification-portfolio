# Full Verification Summary

- 生成时间：2026-08-31 02:00:45 +0800
- 总结果：PASS（通过）
- 总耗时：5 s
- Icarus Verilog：Icarus Verilog version 13.0 (stable) (v13_0)
- Verilator：Verilator 5.050 2026-07-01 rev vUNKNOWN-built20260701

| 验证层次 | 结果 | 关键证据 |
|---|---|---|
| RTL 静态检查 | PASS | Verilator `--lint-only --Wall` 零设计告警 |
| 穷举黑盒回归 | PASS | 64/64 状态/请求组合，64 次下一状态探针 |
| 持续请求公平性 | PASS | 60/60 起点/请求集合，全部请求者均在界限内获授权 |
| 自动检查 | PASS | 1,712 次参考模型与接口不变量比较 |
| SVA 回归 | PASS | 4 条接口性质，零失败 |
| DUT 故障注入 | PASS | 错误回卷指针被黑盒记分板检出 |

> 该文件只会在静态检查、正向回归、断言和预期失败故障注入全部成功后生成。
