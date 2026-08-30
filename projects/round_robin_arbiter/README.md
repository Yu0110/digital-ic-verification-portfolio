# 四请求者轮询仲裁器验证

**简体中文** | [English](README.en.md)

本项目实现并验证一个四请求者轮询仲裁器。设计输出全零或独热组合授权，每次产生非零授权后更新下一轮搜索起点。验证环境采用黑盒方法：参考模型和检查器只观察公开端口，不读取内部轮询指针。

## 已发布证据

| 验证层次 | 结果 | 证据 |
|---|---|---|
| RTL 静态检查 | PASS | Verilator `--lint-only --Wall`，零设计告警 |
| 选择逻辑穷举 | PASS | 4 个轮询起点 × 16 个请求向量，64/64 组合 |
| 状态更新检查 | PASS | 64 次黑盒下一状态探针 |
| 有界公平性 | PASS | 60/60 个起点与非空请求集合场景 |
| 自动检查 | PASS | 1,712 次参考模型与接口不变量比较 |
| 断言回归 | PASS | 4 条 SVA，零失败 |
| 故障注入 | PASS | 请求者 3 错误回卷故障被检出 |

RTL = Register Transfer Level，寄存器传输级。

SVA = SystemVerilog Assertions，SystemVerilog 断言。

## 设计结构

- `req[3:0]` 表示四个请求者是否提出请求；
- `grant[3:0]` 为全零或独热编码，并且只能授权有效请求；
- 两位轮询指针表示下一轮从哪里开始循环搜索；
- 组合逻辑从当前起点选择遇到的第一个有效请求；
- 时序逻辑在非零授权后，把起点推进到获授权者的后一位；
- 没有请求时不授权，轮询起点保持不变。

基础接口把每个非零授权视为服务已经完成。如果真实共享资源存在反压，应增加接受握手，并且只在授权被接受后推进指针。

## 运行方法

在本目录执行：

```bash
make directed    # Icarus Verilog 黑盒穷举回归
make assertions  # Verilator + SVA 断言回归
make faults      # 预期失败的故障注入测试
make verify      # 完整发布回归
make wave        # 生成 VCD 波形的定向回归
```

VCD = Value Change Dump，数值变化转储文件。

## 目录结构

```text
round_robin_arbiter/
├── rtl/                       可综合设计
├── tb/                        参考模型、自动检查与 SVA
├── scripts/                   可重复执行的验证入口
├── docs/                      规格、计划、矩阵和结果
├── reports/                   自动生成的发布汇总
├── Makefile                   稳定命令入口
├── README.md                  中文项目说明
└── README.en.md               English project page
```

建议从 [`docs/reading_order.md`](docs/reading_order.md) 开始阅读。最新回归证据见 [`reports/full_verification_summary.md`](reports/full_verification_summary.md)。

## 当前范围

- 固定四个请求者；
- 低电平有效异步复位；
- 组合授权输出；
- 默认授权即服务完成；
- 单个共享资源。

参数化请求者数量和显式授权接受握手适合作为后续扩展，但不属于当前小型模块已经验证的接口契约。
