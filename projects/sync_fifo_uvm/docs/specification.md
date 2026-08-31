# 同步 FIFO 设计规格

**简体中文** | [English](specification.en.md)

## 参数

| 参数 | 约束 | 说明 |
|---|---:|---|
| `DATA_WIDTH` | `> 0` | 每份存储数据的位宽 |
| `DEPTH` | `>= 2` | 可存储的数据份数 |

指针位宽根据 `DEPTH` 自动计算。数据量位宽根据 `DEPTH + 1` 自动计算，使 `data_count` 能够表示从空状态 0 到满状态 `DEPTH` 的全部数值。

## 接口

| 信号 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| `clk` | 输入 | 1 | 上升沿时钟 |
| `rst_n` | 输入 | 1 | 低电平有效异步复位 |
| `wr_en` | 输入 | 1 | 写请求 |
| `wr_data` | 输入 | `DATA_WIDTH` | 写入数据 |
| `rd_en` | 输入 | 1 | 读请求 |
| `rd_data` | 输出 | `DATA_WIDTH` | 寄存器型读取数据 |
| `empty` | 输出 | 1 | `data_count == 0` 时有效 |
| `full` | 输出 | 1 | `data_count == DEPTH` 时有效 |
| `data_count` | 输出 | `clog2(DEPTH + 1)` | 当前有效数据数量 |

## 操作规则

所有请求均根据时钟上升沿到来前的状态判断是否接受。

| 状态和请求 | 接受的操作 | 结果 |
|---|---|---|
| `wr_en && !full` | 写入 | 数据保存到 `wr_ptr`，写指针前进 |
| `rd_en && !empty` | 读取 | `rd_ptr` 所指数据保存到 `rd_data`，读指针前进 |
| 读写都被接受 | 同时读写 | `data_count` 保持不变 |
| 空状态同时请求读写 | 只写入 | `data_count` 加 1 |
| 满状态同时请求读写 | 只读取 | `data_count` 减 1 |
| 空状态读取 | 均不接受 | 指针、数量和 `rd_data` 保持 |
| 满状态写入 | 均不接受 | 存储阵列、指针、数量和 `rd_data` 保持 |

指针必须在 `DEPTH - 1` 处显式回卷。当 `DEPTH` 不是 2 的整数次幂时，不能依赖二进制指针自然溢出。

## 复位

当 `rst_n` 为低电平时：

- 写指针、读指针和 `data_count` 清零；
- `rd_data` 清零；
- `empty` 有效，`full` 无效；
- 存储阵列不清零，因为指针和数量已经使旧数据失效。

## 参数合法性

`DATA_WIDTH <= 0` 或 `DEPTH < 2` 属于非法配置，仿真必须立即报告致命错误，不能继续使用不合法的数组范围或计数位宽。

FIFO = First In First Out，先进先出队列。

RTL = Register Transfer Level，寄存器传输级。
