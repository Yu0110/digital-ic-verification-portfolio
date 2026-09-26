# Five Injected DUT Faults

[简体中文](dut_fault_matrix.md) | **English**

These deliberate faults test the verification environment; they are not commercial chip defects. All injection parameters default to zero.

| Fault | Injected behavior | Required behavior | Check |
|---|---|---|---|
| Early write | Modify DATA in SETUP | Commit only a completed legal write | no setup write |
| Missing error | Force PSLVERR low | Report invalid accesses on completion | error response |
| Read-only protection failure | Write 04 changes DATA despite reporting error | Report error without changing DATA | commit exactly at completion |
| Wrong reset value | Reset DATA to 1 | Clear DATA asynchronously | asynchronous reset |
| Corrupt read data | Flip bit 0 of DATA read response | Return stored data | readback |

`make faults` tests early writes at waits 0/1/3. `make dut-faults` tests the four other faults separately at wait=1. Each run must exit nonzero and report the specified check, not merely fail for another reason.

Additional fault logs are in `build/dut_faults/fault_<1..4>/run.log`. Negative builds do not change normal build parameters.

The read-only fault demonstrates why checking PSLVERR alone is insufficient: a correct error response may coexist with an illegal side effect. The register comparison detects that corruption.

The read-data fault changes the DUT output, unlike observation corruption in the monitor, which tests whether the comparator rejects bad observations. Reset-value injection fails before normal traffic; detection does not depend on later random readback.
