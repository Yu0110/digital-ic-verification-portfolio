# 同步 FIFO 项目从头到尾自学与运行计划

这份文件是本项目的主学习入口。目标不是把所有文件逐行读完，而是按真实验证流程理解项目，并亲自运行每一层验证。

## 1. 最终目标

完成本计划后，你应该能够独立说明：

1. 同步 FIFO 解决什么问题，接口和边界规则是什么；
2. RTL 如何保存数据、更新指针和计算数据量；
3. testbench 如何产生激励、计算预期结果并自动报错；
4. interface、driver、monitor、reference model 和 scoreboard 如何协作；
5. UVM 验证环境如何从 sequence 走到 DUT，再回到 scoreboard 和 coverage；
6. 断言、功能覆盖率、随机回归和故障注入分别解决什么问题；
7. 如何用一条命令复现整个项目的验证证据。

FIFO = First In First Out，先进先出队列。

RTL = Register Transfer Level，寄存器传输级。

DUT = Design Under Test，被测设计。

UVM = Universal Verification Methodology，通用验证方法学。

SVA = SystemVerilog Assertions，SystemVerilog 断言。

## 2. 先区分哪些文件需要看

### 必须认真阅读

```text
README.md
docs/specification.md
docs/architecture.md
rtl/sync_fifo.sv
tb/sync_fifo_tb.sv
tb/fifo_if.sv
tb/non_uvm/*.sv
uvm/ 中的核心组件文件
docs/results.md
docs/bug_reports/*.md
```

### 需要知道用途，但不用逐行阅读

```text
Makefile
scripts/run_directed.sh
scripts/run_layered.sh
scripts/setup_uvm.sh
scripts/uvm/*.sh
reports/*.md
```

这些文件主要负责编译、运行、检查完成标记和生成报告。先会使用，再在最后阶段挑一个脚本阅读。

### 当前完全不用阅读

```text
.deps/
build/
scripts/uvm_compat/malloc.h
*.out
*.log
*.vcd
```

- `.deps/` 是第三方 UVM 源码；
- `build/` 是自动生成的编译和仿真产物；
- `malloc.h` 是工具兼容文件；
- `.out`、`.log` 和 `.vcd` 分别是仿真程序、日志和波形文件。

VCD = Value Change Dump，数值变化转储文件。

## 3. 推荐时间安排

| 学习阶段 | 建议时间 | 主要结果 |
|---|---:|---|
| 阶段 0：准备与目录认识 | 20 分钟 | 能进入项目并使用 Makefile |
| 阶段 1：规格与 RTL | 90 分钟 | 能手画 FIFO 状态变化 |
| 阶段 2：基础定向 testbench | 90 分钟 | 看懂自动检查如何工作 |
| 阶段 3：非 UVM 分层验证 | 2 小时 | 看懂完整验证数据流 |
| 阶段 4：UVM 核心组件 | 3 小时 | 看懂 transaction 的完整旅程 |
| 阶段 5：覆盖率与随机回归 | 90 分钟 | 理解验证是否充分 |
| 阶段 6：故障注入与项目复盘 | 90 分钟 | 能把项目写进简历并讲清楚 |

不要求一天完成。每完成一个阶段就在下面的清单中打勾。

---

## 阶段 0：准备与目录认识

### 0.1 进入项目

```bash
cd "/Users/mingyu/Desktop/毕业/芯片学习/digital-ic-verification-portfolio/projects/sync_fifo_uvm"
pwd
```

### 0.2 用 Visual Studio Code 打开

```bash
code .
```

### 0.3 查看稳定运行入口

```bash
make help
```

Makefile 是命令入口表。例如 `make directed` 会调用对应的 `.sh` 脚本，再由脚本完成编译和仿真。

### 0.4 先做一次快速基线检查

```bash
make directed
```

预期结尾：

```text
DIRECTED REGRESSION PASS: 5/5 parameter configurations passed.
```

现在只确认环境正常，不要求立刻读懂全部输出。

### 阶段完成标准

- [ ] 我能进入正确目录；
- [ ] 我能用 `code .` 打开项目；
- [ ] 我知道 Makefile 和 `.sh` 脚本的关系；
- [ ] `make directed` 能通过。

---

## 阶段 1：先学规格，再看 RTL

### 1.1 阅读顺序

```text
README.md
docs/specification.md
docs/architecture.md
rtl/sync_fifo.sv
```

### 1.2 阅读规格时只回答这些问题

1. `wr_en=1` 在什么条件下才能成功写入？
2. `rd_en=1` 在什么条件下才能成功读取？
3. 空状态同时读写时，为什么只接受写入？
4. 满状态同时读写时，为什么只接受读取？
5. `rd_data` 在空读、空闲和复位时分别如何变化？
6. 为什么存储数组不需要在复位时逐项清零？

### 1.3 阅读 RTL 的顺序

在 `rtl/sync_fifo.sv` 中依次寻找：

1. `DATA_WIDTH` 和 `DEPTH` 参数；
2. 指针位宽和数据量位宽；
3. 存储数组 `mem`；
4. 写入接受条件和读取接受条件；
5. `empty`、`full` 和 `data_count`；
6. 写指针与读指针的显式回卷；
7. 同时读写时数据量保持不变的分支；
8. 异步复位分支。

不要先背代码。建议在纸上模拟深度为 4 的场景：

```text
写 A → 写 B → 写 C → 读 A → 写 D → 读 B → 读 C → 读 D
```

每一步记录：

```text
存储的有效数据
write pointer
read pointer
data_count
empty
full
rd_data
```

### 1.4 再运行一次 RTL 定向验证

```bash
make directed
```

本次重点观察五种配置：

```text
DATA_WIDTH=8  DEPTH=3
DATA_WIDTH=8  DEPTH=4
DATA_WIDTH=16 DEPTH=4
DATA_WIDTH=8  DEPTH=5
DATA_WIDTH=8  DEPTH=6
```

深度 3、5、6 用于确认非 2 的整数次幂深度也能正确回卷。

### 阶段完成标准

- [ ] 我能解释空、满、正常状态的读写规则；
- [ ] 我能解释三个核心状态：写指针、读指针、数据量；
- [ ] 我能解释为什么 `data_count` 需要表示 0 到 `DEPTH`；
- [ ] 我能解释为什么深度 5 不能只依赖二进制自然溢出回卷；
- [ ] 我能口头说出 RTL 的组合逻辑和时序逻辑分别负责什么。

---

## 阶段 2：基础定向 testbench

### 2.1 阅读文件

```text
tb/sync_fifo_tb.sv
scripts/run_directed.sh
```

先认真看 `sync_fifo_tb.sv`，脚本只看它编译了哪些文件、使用了哪些参数。

### 2.2 阅读 testbench 的顺序

1. DUT 实例化和参数传递；
2. 时钟产生；
3. 参考队列或预期状态变量；
4. 复位任务；
5. 单周期读写任务；
6. 结果比较任务；
7. 19 个测试点如何组合成 14 个测试组；
8. 最后的错误计数和 PASS/FAIL 判定。

重点理解：预期结果不能直接照抄 DUT 的内部信号，而要根据规格独立计算。

### 2.3 单独运行一遍

```bash
make directed
```

运行后可查看日志：

```bash
ls build/directed
```

例如查看深度 5 的结果：

```bash
less build/directed/sync_fifo_8x5.log
```

按 `q` 退出 `less`。

### 2.4 可选：查看波形文件

波形位于：

```text
build/directed/sync_fifo_8x3.vcd
build/directed/sync_fifo_8x4.vcd
build/directed/sync_fifo_16x4.vcd
build/directed/sync_fifo_8x5.vcd
build/directed/sync_fifo_8x6.vcd
```

GTKWave 当前在你的 macOS 环境中不可用，因此这一步可以暂时跳过。自动检查结果不依赖图形波形工具。

### 阶段完成标准

- [ ] 我知道 testbench 如何给 DUT 输入；
- [ ] 我知道 `expected` 和 DUT 实际输出分别从哪里来；
- [ ] 我知道为什么要在正确的时钟边沿驱动和采样；
- [ ] 我知道 `$fatal` 与普通 `$display` 的区别；
- [ ] 我能解释“自检式 testbench”的含义。

---

## 阶段 3：非 UVM 分层验证

这一阶段先不用 UVM 类库，但把测试平台拆分成接近公司项目的组件。

### 3.1 按数据流阅读

```text
tb/fifo_if.sv
tb/non_uvm/fifo_transaction.sv
tb/non_uvm/fifo_generator.sv
tb/non_uvm/fifo_driver.sv
tb/non_uvm/fifo_monitor.sv
tb/non_uvm/fifo_reference_model.sv
tb/non_uvm/fifo_scoreboard.sv
tb/non_uvm/fifo_sva_checker.sv
tb/non_uvm/fifo_boundary_integration_tb.sv
```

不要按字母顺序看。要始终沿着下面的数据流：

```text
generator
    ↓ transaction
driver
    ↓ interface
DUT
    ↓ interface
monitor
    ↓ observed transaction
scoreboard ↔ reference model

SVA checker 与上述流程并行观察接口
```

### 3.2 每个组件只抓一个职责

| 组件 | 只需要先记住的职责 |
|---|---|
| transaction | 保存一笔读写请求和观察结果 |
| generator | 决定要测试哪些事务 |
| driver | 把事务转换成引脚级信号和时序 |
| interface | 集中封装 DUT 信号和时钟边界 |
| monitor | 只观察，不驱动 DUT |
| reference model | 用独立队列预测正确结果 |
| scoreboard | 比较实际结果和预期结果 |
| SVA checker | 连续检查跨周期接口规则 |
| integration top | 实例化并连接所有组件 |

### 3.3 运行分层验证

```bash
make layered
```

预期结果包括：

```text
5/5 参数配置通过
150 次独立 scoreboard 比较
5 条 SVA 零失败
```

### 3.4 重点理解五条断言

阅读：

```text
tb/non_uvm/fifo_sva_checker.sv
```

逐条回答：

1. 复位后状态必须是什么？
2. 空读时哪些状态必须保持？
3. 满写时哪些状态必须保持？
4. 正常同时读写时 `data_count` 为什么保持？
5. `data_count` 为什么不能超过 `DEPTH`？

### 阶段完成标准

- [ ] 我能画出非 UVM 验证数据流；
- [ ] 我能区分 driver 和 monitor；
- [ ] 我能区分 reference model 和 scoreboard；
- [ ] 我知道 interface 为什么能减少连线和时序重复；
- [ ] 我知道 SVA 与普通立即比较的区别。

---

## 阶段 4：UVM 核心组件

不要直接从 30 多个 UVM 文件中乱看。先理解核心生产链，再看测试类。

### 4.1 准备 UVM 依赖

```bash
make setup
make smoke
```

`make smoke` 只确认 UVM、Verilator 和 C++ 工具链可以协同运行。

### 4.2 第一组：事务如何到达 DUT

按顺序阅读：

```text
uvm/fifo_uvm_sequence_item.sv
uvm/fifo_uvm_basic_sequence.sv
uvm/fifo_uvm_coverage_sequence.sv
uvm/fifo_uvm_random_sequence.sv
uvm/fifo_uvm_sequencer.sv
uvm/fifo_uvm_driver.sv
```

对应流程：

```text
sequence 生产 transaction
    ↓
sequencer 调度 transaction
    ↓
driver 获取 transaction
    ↓
driver 通过 virtual interface 驱动 DUT
```

virtual interface = 虚接口，UVM 类访问静态 SystemVerilog 接口实例的句柄。

逐步运行：

```bash
./scripts/uvm/run_uvm_item_smoke.sh
./scripts/uvm/run_uvm_sequence_smoke.sh
./scripts/uvm/run_uvm_driver_smoke.sh
```

每条命令最后都应该出现 `UVM RUNNER PASS`。

### 4.3 第二组：DUT 结果如何回到检查器

按顺序阅读：

```text
uvm/fifo_uvm_monitor.sv
uvm/fifo_uvm_reference_model.sv
uvm/fifo_uvm_scoreboard.sv
uvm/fifo_uvm_coverage.sv
```

对应流程：

```text
monitor 采样接口
    ↓ analysis port 广播
scoreboard 调用 reference model 计算预期结果
    ↓
scoreboard 比较实际值和预期值

coverage 同时接收 monitor 广播并统计命中情况
```

analysis port = 分析端口，用于把观察事务广播给一个或多个订阅者。

逐步运行：

```bash
./scripts/uvm/run_uvm_monitor_smoke.sh
./scripts/uvm/run_uvm_reference_model_smoke.sh
./scripts/uvm/run_uvm_scoreboard_smoke.sh
./scripts/uvm/run_uvm_coverage_smoke.sh
```

### 4.4 第三组：组件如何组装

按顺序阅读：

```text
uvm/fifo_uvm_agent.sv
uvm/fifo_uvm_environment.sv
uvm/fifo_uvm_pkg.sv
uvm/fifo_uvm_smoke_tb.sv
uvm/fifo_uvm_environment_test.sv
```

记住层次关系：

```text
test
└── environment
    ├── agent
    │   ├── sequencer
    │   ├── driver
    │   └── monitor
    ├── scoreboard
    └── coverage collector
```

运行主动和被动 agent：

```bash
./scripts/uvm/run_uvm_environment_smoke.sh
./scripts/uvm/run_uvm_passive_agent_smoke.sh
```

主动 agent 会产生和驱动事务；被动 agent 只监视外部流量。

### 阶段完成标准

- [ ] 我能画出 sequence 到 DUT 的路径；
- [ ] 我能画出 DUT 到 scoreboard 的路径；
- [ ] 我知道 agent 为什么分主动和被动；
- [ ] 我知道 environment 在 `connect_phase` 中连接了什么；
- [ ] 我能解释 virtual interface 和 analysis port。

---

## 阶段 5：覆盖率、随机验证和预期负向测试

### 5.1 先理解三种“通过”

1. 正向测试通过：正确设计和正确环境没有报错；
2. 预期负向测试通过：故意制造的错误被环境准确发现；
3. 覆盖率通过：计划要求的场景都被实际命中。

预期负向测试中出现 `UVM_ERROR` 或 `UVM_FATAL` 可能是正常现象。应查看外层脚本是否最终输出 `UVM RUNNER PASS`。

### 5.2 按完整回归顺序逐一运行

```bash
./scripts/uvm/run_uvm_smoke.sh
./scripts/uvm/run_uvm_item_smoke.sh
./scripts/uvm/run_uvm_sequence_smoke.sh
./scripts/uvm/run_uvm_driver_smoke.sh
./scripts/uvm/run_uvm_monitor_smoke.sh
./scripts/uvm/run_uvm_reference_model_smoke.sh
./scripts/uvm/run_uvm_scoreboard_smoke.sh
./scripts/uvm/run_uvm_scoreboard_fault.sh
./scripts/uvm/run_uvm_environment_smoke.sh
./scripts/uvm/run_uvm_passive_agent_smoke.sh
./scripts/uvm/run_uvm_environment_topology_fault.sh
./scripts/uvm/run_uvm_coverage_smoke.sh
./scripts/uvm/run_uvm_coverage_fault.sh
./scripts/uvm/run_uvm_random_coverage_gate_fault.sh
./scripts/uvm/run_uvm_random_regression.sh
```

这 15 条就是 `make regression` 的内部执行顺序。

### 5.3 最后统一运行

```bash
make regression
```

预期结尾：

```text
UVM REGRESSION PASS: 15/15 UVM FIFO groups passed
```

其中：

```text
11 组正向测试
4 组预期负向测试
20 个固定随机种子
每个种子 200 笔随机事务
总计 4,080 次 scoreboard 比较
```

### 5.4 阅读结果

```text
docs/test_matrix.md
docs/verification_plan.md
docs/results.md
reports/uvm_regression_summary.md
```

### 阶段完成标准

- [ ] 我知道代码覆盖率和功能覆盖率不是一回事；
- [ ] 我能解释 coverpoint、bin 和 cross 的作用；
- [ ] 我知道随机种子为什么必须可记录和重放；
- [ ] 我知道预期负向测试为什么也能显示 PASS；
- [ ] 我能说明 15 组 UVM 回归分别在验证什么层次。

---

## 阶段 6：DUT 故障注入与最终发布回归

UVM 层的预期负向测试检查验证环境本身；这一阶段直接故意破坏 DUT，确认测试平台能发现设计错误。

### 6.1 阅读三个根因报告

```text
docs/bug_reports/BUG-INJECT-001_count_update.md
docs/bug_reports/BUG-INJECT-002_pointer_wrap_root_cause.md
docs/bug_reports/BUG-INJECT-003_full_write_overwrite.md
```

### 6.2 逐个运行 DUT 故障

```bash
./scripts/faults/run_count_update.sh
./scripts/faults/run_pointer_wrap.sh
./scripts/faults/run_full_write_overwrite.sh
```

内部仿真失败是预期行为。外层脚本必须分别输出：

```text
BUG-INJECT-001 PASS
BUG-INJECT-002 PASS
BUG-INJECT-003 PASS
```

也可以统一运行：

```bash
make faults
```

### 6.3 最终完整回归

```bash
make verify
```

这条命令依次执行：

```text
UVM 依赖检查
→ 5 种配置定向回归
→ 非 UVM 分层回归
→ 15 组 UVM 回归
→ 20 个随机种子
→ 3 类 DUT 故障注入
→ 生成发布报告
```

预期结尾：

```text
FULL VERIFICATION PASS
```

最终查看：

```text
reports/full_verification_summary.md
reports/uvm_regression_summary.md
```

### 阶段完成标准

- [ ] 三类 DUT 故障都能被现有检查器发现；
- [ ] 我能区分 scoreboard、SVA 和 coverage 各自能发现什么；
- [ ] `make verify` 完整通过；
- [ ] 我能根据报告说出项目的关键验证数据。

---

## 4. 项目复述模板

完成全部阶段后，不看代码尝试说出下面这段话：

> 我实现并验证了一个参数化同步 FIFO，支持可配置数据位宽和深度，并正确处理非 2 的整数次幂深度下的指针回卷。验证从规格出发，先用自检式定向 testbench 覆盖空、满、同时读写、非法操作、复位和回卷，再建立非 UVM 分层环境和完整 UVM 环境。UVM 环境包含 sequence、sequencer、driver、monitor、agent、独立 reference model、scoreboard 和 coverage collector，并结合 SVA、固定随机种子回归和可重放机制。完整回归覆盖 5 种参数配置、539 次定向检查、15 组 UVM 测试、20 个随机种子和 4,080 次比较，同时通过三类 DUT 故障注入证明验证环境具备检错能力。

## 5. 最终自测问题

如果以下问题能独立回答，这个项目才算真正属于你：

1. 为什么同步 FIFO 仍然需要读写两个指针？
2. 为什么 `data_count` 比存储地址多一位？
3. 为什么深度 5 的指针必须显式回卷？
4. 空状态同时读写为什么不能把新写入数据直接读出？
5. driver 为什么在下降沿驱动，monitor 为什么在状态更新后采样？
6. reference model 为什么不能读取 DUT 的 `empty`、`full` 或指针？
7. scoreboard 和 SVA 的区别是什么？
8. coverage 达到 100% 为什么仍不能证明设计绝对无错误？
9. 为什么预期负向测试出现错误后，外层脚本反而判定 PASS？
10. 如果增加 `ready` 握手或改成异步 FIFO，验证环境需要修改哪些部分？

## 6. 一页命令清单

```bash
cd "/Users/mingyu/Desktop/毕业/芯片学习/digital-ic-verification-portfolio/projects/sync_fifo_uvm"
code .
make help
make setup
make directed
make layered
make smoke
make regression
make faults
make verify
```

只记住一条原则：先读本阶段对应的少量文件，再运行本阶段命令，再用完成标准检查自己，不要从文件夹顶部一路随机点开。
