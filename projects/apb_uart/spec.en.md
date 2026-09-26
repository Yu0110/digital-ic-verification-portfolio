# Peripheral Specification

[简体中文](spec.md) | **English**

The original `apb_regs` teaching baseline uses the APB3 signal subset, one clock, 32-bit data, and 8-bit byte addresses. There are no byte write strobes.

| Signals | Peripheral direction | Meaning |
|---|---|---|
| pclk / presetn | Input | Clock / active-low asynchronous reset |
| psel / penable | Input | Peripheral selected / ACCESS phase |
| pwrite | Input | 1 for write, 0 for read |
| paddr / pwdata | Input | Address / write data |
| prdata | Output | Read data |
| pready / pslverr | Output | Ready to complete / access error |

| Address | Access | Content | Reset value |
|---|---|---|---|
| 0x00 | Read/write | DATA register | 0 |
| 0x04 | Read-only | Constant ID | 1 |

Other addresses, including misaligned addresses, and writes to ID return errors without changing DATA. Error reads return zero. These are this peripheral's requirements, not universal APB error-side-effect rules.

SETUP is `psel=1, penable=0` for one cycle. ACCESS is `psel=1, penable=1`; completion occurs at a rising edge with `pready=1`. A successful write additionally requires write direction and a legal address.

`WAIT_CYCLES` counts ACCESS rising edges with `pready=0`; tested values are 0, 1, and 3. The requester holds address, direction, and write data from SETUP through completion. Back-to-back transfers may keep `psel=1`, but must return to SETUP between transfers.

Reset clears DATA and the wait counter, aborting an unfinished transfer; the testbench also withdraws its request. During reset, pready, pslverr, and prdata are zero. Reading ID after reset returns 1.

Reference: [Arm AMBA APB IHI 0024C](https://documentation-service.arm.com/static/64257f64314e245d086bc8b7). Only its APB3 baseline signals are used here.

## APB + UART Extension

`rtl/apb_uart.sv` is a separate integrated peripheral; the original register map and tests remain intact. It adds `rx_i` and `tx_o`. Serial framing is 8 data bits, no parity, one stop bit (8N1), idle high, least significant bit first. `BAUD_DIV` is the number of `pclk` cycles per serial bit and must be at least 8. Reset is active-low and asynchronous.

| Address | Access | Content |
|---|---|---|
| 0x00 | Write-only | TXDATA: low byte starts transmission; upper 24 bits must be zero |
| 0x04 | Read-only | RXDATA: low byte when valid; completed read clears `rx_valid`; empty read returns zero |
| 0x08 | Read-only | STATUS: bit 0 `tx_busy`, bit 1 `rx_valid`, bit 2 `rx_overrun`, bit 3 `framing_error` |
| 0x0C | Read-only | BAUDDIV: fixed `BAUD_DIV` parameter |

Invalid addresses, directions, nonzero TXDATA upper bits, and writes while the transmitter is busy return `pslverr=1` on completion without side effects; error reads return zero. The receiver has a one-byte buffer: if the previous byte has not been read, the new frame is dropped and `rx_overrun` is set. A low sampled stop bit drops the frame and sets `framing_error`. Error flags are sticky until reset. Reset aborts active frames and returns `tx_o` high. This version has no FIFO, parity, flow control, or interrupts.

The extension uses the same APB3 SETUP/ACCESS and `WAIT_CYCLES` rules. TXDATA launches and RXDATA pops only on successful completion edges. `make uart` tests 8/16 clocks per bit with 0/1/3 APB wait cycles.
