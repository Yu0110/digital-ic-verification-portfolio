# Four-requester Round-robin Arbiter

## 项目目标

四个请求者共享一个资源时，每个周期最多授权一个请求者，并让持续请求者轮流获得服务，避免固定优先级造成长期饥饿。

round-robin = 轮询调度。  
arbiter = 仲裁器。

## 当前状态

- [x] 规格说明
- [x] RTL 实现
- [x] 自检式 testbench
- [x] 验证计划
- [x] 测试矩阵
- [x] 21 项定向检查
- [x] 错误注入和定位报告
- [x] 面试表达

## 接口

| 信号 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| `clk` | 输入 | 1 | 上升沿更新轮询起点 |
| `rst_n` | 输入 | 1 | 低电平有效异步复位 |
| `req` | 输入 | 4 | 四个请求者的请求向量 |
| `grant` | 输出 | 4 | 全零或 one-hot 授权向量 |

one-hot = 独热编码，多个位中最多只有一位有效。

## 设计结构

- 组合逻辑从 `priority_ptr` 开始循环搜索，生成 `grant` 和 `priority_ptr_next`；
- 时序逻辑在时钟上升沿保存新的轮询起点；
- 无请求时不授权且保持指针；
- 基础版本假设非零授权代表服务完成，因此授权后立即推进指针。

## 文件说明

- [`spec.md`](spec.md)：接口、功能规则、公平性和边界；
- [`verification_plan.md`](verification_plan.md)：验证目标、策略和退出标准；
- [`test_matrix.md`](test_matrix.md)：21 项测试与检查器映射；
- [`rtl/round_robin_arbiter.sv`](rtl/round_robin_arbiter.sv)：被测设计；
- [`tb/round_robin_arbiter_tb.sv`](tb/round_robin_arbiter_tb.sv)：自检式测试平台；
- [`bug_reports/bug_001_wrong_wrap_pointer.md`](bug_reports/bug_001_wrong_wrap_pointer.md)：错误注入和定位过程；
- [`interview.md`](interview.md)：30 秒、1 分钟和追问回答。

DUT = Design Under Test，被测设计。

## 运行方法

从仓库根目录运行：

```bash
./scripts/run_all.sh
```

也可以在本目录手动运行：

```bash
iverilog -g2012 -s round_robin_arbiter_tb -o round_robin_arbiter.out \
  rtl/round_robin_arbiter.sv tb/round_robin_arbiter_tb.sv
vvp round_robin_arbiter.out
```

## 验证结果

自检式 testbench 执行 21 项检查，覆盖复位、无请求、四个单请求、四请求持续轮转、稀疏请求、跳过、回卷、无请求保持、独热授权和请求授权一致性。

```text
ALL TESTS PASSED: 21 cases
```

错误注入把请求者 3 获授权后的下一指针从 0 改为 1。testbench 首先报告指针不匹配，随后捕获错误状态传播，证明测试平台能够发现该类状态更新错误。

## 当前限制

- 请求者数量固定为 4；
- 没有接受握手，默认授权即服务完成；
- 尚未加入 SystemVerilog Assertions 和功能覆盖率；
- 当前公平性通过定向场景检查，后续可增加参数化和随机验证。

SVA = SystemVerilog Assertions，SystemVerilog 断言。

## 30 秒面试讲法

> 我实现了一个四请求者轮询仲裁器。组合逻辑从当前轮询起点循环搜索，只授权第一个有效请求者；时序逻辑保存下一次搜索起点。相比固定优先级，它能避免持续请求者长期饥饿。我编写了自检式 testbench，完成 21 项复位、回卷、稀疏请求、公平性和合法性检查，并通过错误注入确认测试平台能捕获错误的指针更新。
