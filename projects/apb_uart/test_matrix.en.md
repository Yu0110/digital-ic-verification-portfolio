# APB Baseline Directed Test Matrix

[简体中文](test_matrix.md) | **English**

| Scenario | Check |
|---|---|
| DATA / ID reads after reset | 0 / 1 respectively |
| Write and read back 2A, FFFFFFFF, A5A55A5A | Exact data match |
| Write read-only address 04 | Error; ID and DATA unchanged |
| Read/write invalid address 08 or misaligned address 01 | Error; DATA unchanged; error reads return zero |
| Back-to-back traffic | PSEL remains asserted; each request still has SETUP |
| Wait settings 0/1/3 | Exact wait duration; no early SETUP/wait updates |
| Reset after nonzero data | DATA becomes zero |
| Reset during unfinished write | During SETUP for wait=0, waiting ACCESS otherwise |
| Reads/writes after reset | Normal operation resumes |
| Injected early write | Must report `no setup write` |

Each basic run completes 20 transfers and aborts one additional request by reset. The aborted request is not counted as completed. The matrix does not exhaust all invalid addresses or claim complete coverage. Additional suites are described in the [verification plan](verification_plan.en.md).

## APB + UART Extension

| Scenario | Check |
|---|---|
| TXDATA write and serial output | Starts after completion; start bit, LSB-first data, stop bit, idle level |
| TX-to-RX loopback | The transmitted frame returns through the receiver and RXDATA matches the byte |
| Write while transmitter busy | APB error; active frame is not replaced |
| RX serial input and RXDATA read | 8N1 frame becomes a byte; completed read clears `rx_valid` |
| Receive buffer occupied | New frame dropped, old byte retained, `rx_overrun` set |
| Low stop bit | No new byte; `framing_error` set |
| Reset during transmission | `tx_o` immediately high; state and errors cleared |
| Invalid address, direction, or nonzero TXDATA upper bits | Error with no side effect |
| 8/16 clocks per bit x 0/1/3 APB wait cycles | Identical self-checking suite passes in six configurations |
