# 对外只暴露稳定的回归入口，具体编译参数由 scripts/ 中的脚本维护。
.PHONY: help setup directed layered smoke regression faults verify fault-count fault-pointer fault-full

help:
	@printf '%s\n' \
		'make setup       Install and verify the pinned UVM dependency' \
		'make directed    Run five parameterized directed regressions' \
		'make layered     Run the non-UVM layered boundary regression' \
		'make smoke       Run the minimal UVM toolchain smoke test' \
		'make regression  Run all 15 UVM positive and expected-negative groups' \
		'make faults      Prove that all three injected DUT faults are detected' \
		'make verify      Run the complete publishable verification suite'

setup:
	./scripts/setup_uvm.sh

directed:
	./scripts/run_directed.sh

layered:
	./scripts/run_layered.sh

smoke:
	./scripts/uvm/run_uvm_smoke.sh

regression:
	./scripts/uvm/run_regression.sh

verify:
	./scripts/run_all.sh

faults: fault-count fault-pointer fault-full

fault-count:
	./scripts/faults/run_count_update.sh

fault-pointer:
	./scripts/faults/run_pointer_wrap.sh

fault-full:
	./scripts/faults/run_full_write_overwrite.sh
