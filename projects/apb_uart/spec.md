# APB 外设规格

**简体中文** | [English](spec.en.md)

以下首先描述保留的 `apb_regs` 教学基线。它采用 APB3 信号集合，单时钟、32 位数据、8 位字节地址，不含字节写使能。

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

## APB + UART 扩展

`rtl/apb_uart.sv` 是独立的集成外设，不改变上述基线地址和测试。新增 `rx_i` 输入、`tx_o` 输出；串口为 8 数据位、无校验、1 停止位（8N1），空闲电平为 1，低位先发。`BAUD_DIV` 表示每串行位占用的 `pclk` 周期数，最小值为 8；复位为低有效异步复位。

| 地址 | 权限 | 内容 |
|---|---|---|
| 0x00 | 只写 | TXDATA：写入低 8 位启动发送；高 24 位必须为 0 |
| 0x04 | 只读 | RXDATA：有数据时返回低 8 位；完成读后清除 `rx_valid`，空读返回 0 |
| 0x08 | 只读 | STATUS：bit0 `tx_busy`、bit1 `rx_valid`、bit2 `rx_overrun`、bit3 `framing_error` |
| 0x0C | 只读 | BAUDDIV：返回固定参数 `BAUD_DIV` |

其他地址、错误方向、高位非零的 TXDATA 写入、发送忙时再写 TXDATA 均在完成时返回 `pslverr=1`，没有副作用；错误读返回 0。接收缓冲深度为一个字节：上一字节未读时，新帧被丢弃，并置位 `rx_overrun`。停止位采样为低则丢弃该帧，并置位 `framing_error`。两种错误标志保持到复位；复位还终止正在发送或接收的帧，并使 `tx_o` 返回空闲高电平。本版没有 FIFO、奇偶校验、流控或中断。

扩展沿用 APB3 SETUP/ACCESS 与 `WAIT_CYCLES` 规则；TXDATA 写入和 RXDATA 弹出只在成功传输的完成沿发生。`make uart` 对 8/16 时钟每位及 0/1/3 拍等待各运行一组自检。
