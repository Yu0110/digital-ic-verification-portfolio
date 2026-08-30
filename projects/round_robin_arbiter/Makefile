# 对外只保留稳定入口，具体工具参数由 scripts/ 统一维护。
.PHONY: help lint directed assertions faults verify wave

help:
	@printf '%s\n' \
		'make lint        Run Verilator RTL lint' \
		'make directed    Run the exhaustive black-box regression' \
		'make assertions  Run the regression with four SVA properties' \
		'make faults      Prove that the injected wrap defect is detected' \
		'make verify      Run the complete publishable verification suite' \
		'make wave        Run the directed regression and write a VCD waveform'

lint:
	./scripts/run_lint.sh

directed:
	./scripts/run_directed.sh

assertions:
	./scripts/run_assertions.sh

faults:
	./scripts/run_fault_injection.sh

verify:
	./scripts/run_all.sh

wave:
	DUMP_WAVE=1 ./scripts/run_directed.sh
