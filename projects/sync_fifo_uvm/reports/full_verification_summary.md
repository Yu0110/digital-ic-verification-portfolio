# Full Verification Summary

- 生成时间：2026-08-31 01:31:41 +0800
- 总结果：PASS（通过）
- 总耗时：101 s
- Icarus Verilog：Icarus Verilog version 13.0 (stable) (v13_0)
- Verilator：Verilator 5.050 2026-07-01 rev vUNKNOWN-built20260701

| 验证层次 | 结果 | 关键证据 |
|---|---|---|
| 参数化定向回归 | PASS | 5/5 配置，539 次自动检查 |
| 非 UVM 分层回归 | PASS | 5/5 配置，150 次独立记分板比较，五条 SVA 零失败 |
| UVM 总回归 | PASS | 15/15 组，11 个正向、4 个预期负向 |
| UVM 随机回归 | PASS | 20 个固定种子，4,080 次比较，首种子重放一致 |
| DUT 故障注入 | PASS | 数量更新、指针回卷、满写覆盖三类故障均被检出 |

> 该文件只会在上述全部验证入口成功结束后生成。详细 UVM 分组结果见 `uvm_regression_summary.md`。
