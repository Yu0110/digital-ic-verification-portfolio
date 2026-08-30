# UVM Regression Summary

- 生成时间：2026-08-30 17:45:17 +0800
- 结果：PASS（通过）
- 总通过数：15/15
- 正向测试：11/11
- 预期负向测试：4/4
- 总耗时：96 s
- 详细日志：保存在本次运行的临时目录中，不纳入仓库

| 组号 | 测试 | 类型 | 结果 | 耗时 |
|---|---|---|---|---:|
| 1 | 最小 UVM 工具链 | 正向 | PASS | 35 s |
| 2 | sequence item 事务对象 | 正向 | PASS | 38 s |
| 3 | sequence 与 sequencer 握手 | 正向 | PASS | 1 s |
| 4 | driver 与真实 DUT 集成 | 正向 | PASS | 2 s |
| 5 | monitor 与 analysis port | 正向 | PASS | 1 s |
| 6 | 独立 reference model 合同 | 正向 | PASS | 1 s |
| 7 | scoreboard 正向比较 | 正向 | PASS | 2 s |
| 8 | scoreboard 六字段故障注入 | 预期负向 | PASS | 1 s |
| 9 | 主动 agent 与 environment | 正向 | PASS | 1 s |
| 10 | 被动 agent 外部流量 | 正向 | PASS | 1 s |
| 11 | environment 漏接订阅者故障 | 预期负向 | PASS | 2 s |
| 12 | 16 笔定向覆盖闭合 | 正向 | PASS | 1 s |
| 13 | 四类非法覆盖样本 | 预期负向 | PASS | 2 s |
| 14 | 随机覆盖门槛故障 | 预期负向 | PASS | 1 s |
| 15 | 20-seed 随机回归与重放 | 正向 | PASS | 7 s |

> 预期负向测试的 PASS 表示验证环境准确检出了故意注入的错误，不表示被测设计发生了未处理失败。
