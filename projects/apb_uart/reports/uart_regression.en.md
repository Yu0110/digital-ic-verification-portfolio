# UART Extension Regression

[简体中文](uart_regression.md) | **English**

On 2026-09-26, `make -C projects/apb_uart regression` and the portfolio quick regression both exited zero locally. The six UART configurations each completed 27 APB transfers, 162 in total.

| Clocks per bit | APB wait cycles | Transfers | Checks |
|---:|---:|---:|---:|
| 8 | 0 | 27 | 91 |
| 8 | 1 | 27 | 94 |
| 8 | 3 | 27 | 100 |
| 16 | 0 | 27 | 91 |
| 16 | 1 | 27 | 94 |
| 16 | 3 | 27 | 100 |

Checks cover TX framing and bit order, TX-to-RX loopback, independent RX stimulus, busy-write rejection, one-byte receive overrun, invalid stop bit, access permissions, APB waits, and asynchronous reset. The original APB directed, random, protocol, and fault-injection suites also passed. No UVM, UART random-coverage closure, UART fault injection, or real-silicon defect discovery is claimed. Build logs remain under Git-ignored `build/uart/`.
