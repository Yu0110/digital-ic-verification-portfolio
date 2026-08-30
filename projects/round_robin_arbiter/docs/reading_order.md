# 阅读顺序

建议按以下顺序检查项目：

1. [`README.md`](../README.md)：项目目标、验证证据和运行入口。
2. [`specification.md`](specification.md)：接口契约、公平性和限制。
3. [`architecture.md`](architecture.md)：设计状态、搜索逻辑和接口取舍。
4. [`rtl/round_robin_arbiter.sv`](../rtl/round_robin_arbiter.sv)：可综合实现。
5. [`verification_plan.md`](verification_plan.md)：黑盒验证策略和退出标准。
6. [`test_matrix.md`](test_matrix.md)：穷举交叉、公平性和故障注入映射。
7. [`tb/round_robin_arbiter_tb.sv`](../tb/round_robin_arbiter_tb.sv)：独立参考模型与自动检查。
8. [`tb/round_robin_arbiter_sva.sv`](../tb/round_robin_arbiter_sva.sv)：接口级断言。
9. [`results.md`](results.md)：已发布验证结果。
10. [`bug_reports/BUG-INJECT-001_wrong_wrap_pointer.md`](bug_reports/BUG-INJECT-001_wrong_wrap_pointer.md)：故障注入与根因。

学习笔记和面试表达保留在 [`learning_notes.md`](learning_notes.md) 与 [`interview_guide.md`](interview_guide.md)，不属于运行项目所必需的文件。
