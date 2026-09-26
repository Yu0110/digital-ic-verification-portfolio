# 本轮统一走读

**简体中文** | [English](protocol_walkthrough.en.md)

## 看文件的顺序

1. `tb/apb_roles_tb.sv`：drive 发请求，监视进程采集完成沿，score 判断结果。
2. `tb/apb_protocol_checker.sv`：独立观察相邻两个上升沿的协议行为。
3. `tb/apb_protocol_tb.sv`：专门构造正确和错误轨迹，测试检查器本身。
4. `scripts/run_protocol.sh`：要求错误版准确报出指定错误。

## 检查器记住什么

- `prev_setup`：上一拍是准备阶段。
- `prev_wait`：上一拍是尚未完成的访问。
- `prev_done`：上一拍刚完成传输。
- `prev_addr/prev_write/prev_data`：上一拍的请求内容。

每个上升沿先检查，再把当前值保存成下一拍使用的历史值。不要先覆盖历史，否则会拿当前值和自己比较。

## 三条主线

上一拍准备：这一拍必须进入访问，地址、方向及写数据保持。

上一拍等待：这一拍仍在访问，请求保持；即使这一拍已经 ready，也不能在完成前换请求。

上一拍完成：这一拍 PENABLE 必须低，可以空闲，也可以准备下一笔。

复位清除历史阶段，取消等待保持义务。计数器保留累计命中次数，只用于证明测试确实走到了检查分支，不是功能覆盖率。

## 为什么保留原测试

协议检查器看总线，记分板看读写结果，原测试额外看内部寄存器更新时机。职责不同，不能因为增加协议检查就删掉原有检查。

## 负向用例

| 用例 | 人为错误 | 预期错误标记 |
|---|---|---|
| no_setup | 直接进入访问 | NO_SETUP |
| enable_only | 未选中却拉高使能（单外设约束） | ENABLE_WITHOUT_SELECT |
| setup_addr | 准备到访问时换地址 | ADDR_STABLE |
| setup_stuck | 准备阶段持续两拍 | PHASE_HOLD |
| wait_addr | 等待时换地址 | ADDR_STABLE |
| wait_data | 等待时换写数据 | DATA_STABLE |
| wait_dir | 等待时切换读写 | DIR_STABLE |
| wait_drop | 等待时撤销请求 | PHASE_HOLD |
| done_addr | 最后完成沿才换地址 | ADDR_STABLE |
| done_stuck | 完成后仍保持访问阶段 | EXIT_ACCESS |

这些是检查器的教学故障，不是发现了十个真实 DUT 缺陷。

## 实际操作

在项目目录运行 `make regression`。协议独立测试日志在 `build/protocol/`；正常日志是 `legal.log`，负向日志按用例名保存。

复习时任选 `done_addr`：先说出上一拍和当前拍的值，再指出哪条检查应该报错。无需背检查次数，不把看懂代码算作独立调试通过。
