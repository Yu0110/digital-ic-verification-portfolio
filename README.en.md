# Digital Integrated Circuit Verification Portfolio

[简体中文](README.md) | **English**

This repository presents reproducible digital Integrated Circuit (IC, 集成电路) verification projects. Each project documents the complete workflow from specification analysis and verification planning to testbench implementation, regression evidence, and defect diagnosis.

## Projects

| Project | Verification focus | Published evidence | Status |
|---|---|---|---|
| [Parameterized synchronous FIFO with UVM verification](projects/sync_fifo_uvm/README.en.md) | Parameterization, layered testbench, SVA, UVM, constrained random testing, functional coverage, and fault injection | 5 configurations, 539 directed checks, 15/15 UVM regression groups, 20 random seeds, 4,080 comparisons, and 3/3 injected faults detected | Complete |
| [Four-requester round-robin arbiter](projects/round_robin_arbiter/README.en.md) | Black-box reference model, exhaustive state verification, bounded fairness, SVA, and fault injection | 64/64 state/request combinations, 60/60 fairness scenarios, 1,712 comparisons, 4 SVA properties, and 1/1 fault detected | Complete |
| APB-UART UVM verification | Register interface, serial transmit/receive behavior, protocol checks, and coverage | To be published after the specification is finalized | Planned |

FIFO = First In First Out (先进先出队列).

UVM = Universal Verification Methodology (通用验证方法学).

SVA = SystemVerilog Assertions (SystemVerilog 断言).

APB = Advanced Peripheral Bus (高级外设总线).

UART = Universal Asynchronous Receiver/Transmitter (通用异步收发器).

## Verification Workflow

Each project follows this closed-loop process:

```text
Specification -> Verification plan -> Test matrix -> Stimulus and monitoring
              -> Reference model and scoreboard -> Assertions and coverage
              -> Automated regression -> Fault injection -> Results and bug reports
```

The synchronous FIFO project contains the complete engineering-style verification environment. The round-robin arbiter demonstrates the same specification-driven method on a smaller design.

## Quick Start

The quick regression requires Icarus Verilog, GNU Make, and Bash. The full regression additionally requires Verilator, Git, and a C++ toolchain.

Run the quick checks for both published projects:

```bash
./scripts/run_all.sh
```

Run the complete publishable suites for both projects, including assertions, constrained random testing, and fault injection:

```bash
./scripts/run_all.sh --full
```

Individual project targets are also available:

```bash
make -C projects/round_robin_arbiter directed
make -C projects/round_robin_arbiter verify
make -C projects/sync_fifo_uvm directed
make -C projects/sync_fifo_uvm verify
```

On the first full run, the setup script installs the pinned UVM 2020.3.1 source under `.deps/`. Third-party dependencies, logs, waveforms, and build products are excluded from version control.

## Repository Layout

```text
digital-ic-verification-portfolio/
├── projects/
│   ├── round_robin_arbiter/   Four-requester round-robin arbiter
│   └── sync_fifo_uvm/         Parameterized synchronous FIFO and verification environment
├── scripts/
│   └── run_all.sh             Portfolio regression entry point
├── README.md                  Simplified Chinese home page
├── README.en.md               English home page
└── LICENSE
```

## Terminology

| Abbreviation | Full name | Chinese meaning |
|---|---|---|
| IC | Integrated Circuit | 集成电路 |
| DV | Design Verification | 设计验证 |
| RTL | Register Transfer Level | 寄存器传输级 |
| DUT | Design Under Test | 被测设计 |
| FIFO | First In First Out | 先进先出队列 |
| UVM | Universal Verification Methodology | 通用验证方法学 |
| SVA | SystemVerilog Assertions | SystemVerilog 断言 |
| APB | Advanced Peripheral Bus | 高级外设总线 |
| UART | Universal Asynchronous Receiver/Transmitter | 通用异步收发器 |

## Publication Policy

This repository contains only original, sanitized, regression-tested work whose design decisions can be explained. Resumes, contact details, job-search records, course materials, credentials, and unlicensed code are excluded.

## License

[MIT License](LICENSE)
