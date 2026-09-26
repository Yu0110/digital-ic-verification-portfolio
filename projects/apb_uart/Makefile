.PHONY: test faults lint wave roles protocol regression random dut-faults

dut-faults:
	bash scripts/run_dut_faults.sh

random:
	bash scripts/run_random.sh

protocol:
	bash scripts/run_protocol.sh

regression:
	$(MAKE) test
	$(MAKE) faults
	$(MAKE) dut-faults
	$(MAKE) roles
	$(MAKE) protocol
	$(MAKE) random
	$(MAKE) lint

roles:
	bash scripts/run_roles.sh

test:
	bash scripts/run.sh test

faults:
	bash scripts/run.sh faults

lint:
	verilator --lint-only -Wall rtl/apb_regs.sv

wave:
	bash scripts/run.sh wave
