# Digital IC Verification Portfolio

这是一个持续更新的数字 IC 验证作品集，重点展示从规格理解、验证计划、测试实现、错误定位到结果表达的完整过程。

IC = Integrated Circuit，集成电路。  
DV = Design Verification，设计验证。  
RTL = Register Transfer Level，寄存器传输级。

## 当前项目

| 项目 | 状态 | 当前证据 |
|---|---|---|
| [四请求者 round-robin arbiter](projects/round_robin_arbiter/README.md) | 已完成第一版 | 规格、RTL、自检式 testbench、21 项定向检查、错误注入报告 |
| 同步 FIFO 非 UVM 验证 | 计划中 | 完成后发布 |
| 同步 FIFO UVM 验证 | 计划中 | 完成后发布 |
| APB-UART UVM 验证 | 计划中 | 完成后发布 |

round-robin = 轮询，一种按顺序公平服务多个请求者的策略。  
FIFO = First In First Out，先进先出队列。  
UVM = Universal Verification Methodology，通用验证方法学。  
APB = Advanced Peripheral Bus，高级外设总线。  
UART = Universal Asynchronous Receiver/Transmitter，通用异步收发器。

## 当前能力证据

- 从自然语言需求整理接口、状态和功能规则；
- 把规格拆成验证计划与测试矩阵；
- 编写 SystemVerilog RTL 和自检式 testbench；
- 检查复位、正常、边界、公平性和非法输出；
- 通过错误注入验证 testbench 的检错能力；
- 使用 Icarus Verilog 运行可重复仿真；
- 为项目准备 30 秒和 1 分钟面试表达。

SystemVerilog = 系统级 Verilog 硬件描述与验证语言。  
testbench = 测试平台 / 测试代码。

## 快速运行

环境要求：Icarus Verilog。

```bash
./scripts/run_all.sh
```

当前预期结果：

```text
ALL TESTS PASSED: 21 cases
ALL PORTFOLIO TESTS PASSED: 1/1
```

## 目录结构

```text
projects/
  round_robin_arbiter/
    rtl/
    tb/
    bug_reports/
    README.md
    spec.md
    verification_plan.md
    test_matrix.md
    interview.md
scripts/
  run_all.sh
```

## 发布原则

这里只发布原创、脱敏、已经测试且能够解释的内容。简历、电话号码、私人邮箱、求职记录、课程资料、账号密钥和无法确认授权的代码不会进入本仓库。
