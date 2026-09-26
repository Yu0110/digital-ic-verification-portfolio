# Peripheral Specification

[简体中文](spec.md) | **English**

The design uses the APB3 signal subset, one clock, 32-bit data, and 8-bit byte addresses. There are no byte write strobes.

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
