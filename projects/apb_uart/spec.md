# 第一版规格

**简体中文** | [English](spec.en.md)

采用 APB3 信号集合，单时钟、32 位数据、8 位字节地址，不含字节写使能。

| 信号 | 方向（相对外设） | 用途 |
|---|---|---|
| pclk / presetn | 输入 | 时钟 / 低有效异步复位 |
| psel / penable | 输入 | 选中外设 / 访问阶段 |
| pwrite | 输入 | 1 写，0 读 |
| paddr / pwdata | 输入 | 地址 / 写数据 |
| prdata | 输出 | 读数据 |
| pready / pslverr | 输出 | 可以完成 / 本次访问错误 |

| 地址 | 权限 | 内容 | 复位值 |
|---|---|---|---|
| 0x00 | 读写 | DATA，数据寄存器 | 0 |
| 0x04 | 只读 | ID，固定标识 | 1 |

以下错误处理是本项目约定，不是所有 APB 外设的统一要求：其他地址（含不对齐地址）、写 ID 均返回错误，不改变 DATA；错误读返回 0。

准备阶段：`psel=1, penable=0`，持续一拍。访问阶段：`psel=1, penable=1`，在上升沿遇到 `pready=1` 才完成。成功写还要求 `pwrite=1` 且地址合法。

`WAIT_CYCLES` 指每笔访问中 `pready=0` 的上升沿数量，本轮验证 0、1、3。准备到访问以及等待期间，发起方保持地址、方向和写数据不变。连续访问允许保持 psel=1，但两笔之间必须回到准备阶段。

复位清零 DATA 和等待计数，取消未完成访问；测试平台同时撤销请求。复位期间 pready、pslverr、prdata 为 0。ID 在正常读取时仍为 1。

协议参考：[Arm AMBA APB IHI 0024C](https://documentation-service.arm.com/static/64257f64314e245d086bc8b7)。本实现只使用其中 APB3 基础信号。
