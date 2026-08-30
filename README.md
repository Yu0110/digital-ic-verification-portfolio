# 数字集成电路验证作品集

**简体中文** | [English](README.en.md)

本仓库收录可复现的数字集成电路验证项目，重点展示从规格分析、验证计划、测试平台实现到回归结果和缺陷定位的完整工作流程。

## 项目一览

| 项目 | 验证重点 | 已发布证据 | 状态 |
|---|---|---|---|
| [参数化同步 FIFO 与 UVM 验证](projects/sync_fifo_uvm/README.md) | 参数化设计、分层测试平台、SVA、UVM、约束随机、功能覆盖率、故障注入 | 5 种参数配置、539 次定向检查、15/15 组 UVM 回归、20 个随机种子、4,080 次比较、3/3 类故障检出 | 已完成 |
| [四请求者轮询仲裁器](projects/round_robin_arbiter/README.md) | 黑盒参考模型、穷举状态验证、有界公平性、SVA、故障注入 | 64/64 状态/请求组合、60/60 公平性场景、1,712 次比较、4 条 SVA、1/1 故障检出 | 已完成 |
| APB-UART UVM 验证 | 寄存器接口、串口收发、协议检查与覆盖率 | 规格确定后发布 | 规划中 |

FIFO = First In First Out，先进先出队列。

UVM = Universal Verification Methodology，通用验证方法学。

SVA = SystemVerilog Assertions，SystemVerilog 断言。

APB = Advanced Peripheral Bus，高级外设总线。

UART = Universal Asynchronous Receiver/Transmitter，通用异步收发器。

## 验证流程

每个项目按以下闭环组织：

```text
规格说明 -> 验证计划 -> 测试矩阵 -> 激励与监视 -> 参考模型与记分板
        -> 断言与覆盖率 -> 自动回归 -> 故障注入 -> 结果与缺陷报告
```

同步 FIFO 项目包含完整的工程化验证环境，轮询仲裁器项目用于展示较小模块的规格驱动验证方法。

## 快速运行

快速回归需要 Icarus Verilog、GNU Make 和 Bash。完整回归还需要 Verilator、Git 和 C++ 编译工具链。

运行两个已发布项目的快速检查：

```bash
./scripts/run_all.sh
```

运行两个项目的完整可发布回归，包括断言、约束随机和故障注入：

```bash
./scripts/run_all.sh --full
```

也可以只运行单个项目：

```bash
make -C projects/round_robin_arbiter directed
make -C projects/round_robin_arbiter verify
make -C projects/sync_fifo_uvm directed
make -C projects/sync_fifo_uvm verify
```

首次执行完整回归时，脚本会下载固定版本的 UVM 2020.3.1 到项目内的 `.deps/` 目录。依赖、日志、波形与构建产物均被版本控制忽略。

## 仓库结构

```text
digital-ic-verification-portfolio/
├── projects/
│   ├── round_robin_arbiter/   四请求者轮询仲裁器
│   └── sync_fifo_uvm/         参数化同步 FIFO 与完整验证环境
├── scripts/
│   └── run_all.sh             作品集统一回归入口
├── README.md                  简体中文首页
├── README.en.md               English home page
└── LICENSE
```

## 术语对照

| 缩写 | 英文全称 | 中文释义 |
|---|---|---|
| IC | Integrated Circuit | 集成电路 |
| DV | Design Verification | 设计验证 |
| RTL | Register Transfer Level | 寄存器传输级 |
| DUT | Design Under Test | 被测设计 |
| FIFO | First In First Out | 先进先出队列 |
| UVM | Universal Verification Methodology | 通用验证方法学 |
| SVA | SystemVerilog Assertions | SystemVerilog 断言 |
| APB | Advanced Peripheral Bus | 高级外设总线 |
| UART | Universal Asynchronous Receiver/Transmitter | 通用异步收发器 |

## 发布原则

仓库只保留原创、脱敏、经过回归且能够说明设计取舍的内容。个人简历、联系方式、求职记录、课程资料、账号凭据和未经授权的代码不进入本仓库。

## 开源许可

[MIT License](LICENSE)
