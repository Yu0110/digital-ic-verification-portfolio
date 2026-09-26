// 时间单位 1ns、精度 1ps：下面的 #5 表示等 5ns。
`timescale 1ns/1ps
// APB（Advanced Peripheral Bus，高级外设总线）定向自检测试平台。
module apb_regs_tb;
    // 运行脚本分别传入 0、1、3，测试不同等待拍数。
    parameter int unsigned WAIT_CYCLES = 0;
    // 正常为 0；故障测试设为 1，故意让电路在准备阶段提前写入。
    parameter bit INJECT_EARLY_WRITE = 0;
    parameter int unsigned INJECT_FAULT = 0; // 额外四种 DUT 人为故障，正常保持 0。
    logic clk = 0;
    // 每 5ns 翻转一次，完整时钟周期为 10ns。
    always #5 clk = ~clk;
    // 测试平台驱动这些输入：复位、选中、阶段、读写方向、地址和写数据。
    logic rst_n = 0;
    logic psel = 0, penable = 0, pwrite = 0;
    logic [7:0] paddr = 0;
    logic [31:0] pwdata = 0;
    // 从外设观察响应：读数据、就绪、错误。
    wire [31:0] prdata;
    wire pready, pslverr;
    // 独立记录地址 00 应有的值，不从电路内部抄答案。
    logic [31:0] expected = 0;
    // checks 是检查次数；transfers 只统计已完成的传输。
    int checks = 0, transfers = 0;

    // 实例化 DUT（Design Under Test，被测设计），把测试信号接到外设。
    // .psel 是 .psel(psel) 的简写；.pclk(clk) 则连接不同名称的信号。
    apb_regs #(.WAIT_CYCLES(WAIT_CYCLES),
               .INJECT_EARLY_WRITE(INJECT_EARLY_WRITE), .INJECT_FAULT(INJECT_FAULT)) dut (
        .pclk(clk), .presetn(rst_n), .psel, .penable, .pwrite,
        .paddr, .pwdata, .prdata, .pready, .pslverr
    );

    // 公共检查函数：失败时打印检查名称和时间，并立即终止仿真。
    // automatic 表示每次调用有独立的局部存储；此处声明的是 task（任务）。
    task automatic check(input bit ok, input string label);
        checks++;
        if (!ok) $fatal(1, "CHECK_FAIL %s time=%0t", label, $time);
    endtask

    // 一笔完整传输：wr=1 写、wr=0 读；addr 为地址；value 为写数据。
    // 读操作不使用 value。期望结果由请求和规格计算。
    task automatic transfer(input bit wr, input logic [7:0] addr,
                            input logic [31:0] value);
        bit error_expected;
        int waits;
        // 地址只能是 00 或 04；04 只读。提前判断本次是否应该报错。
        error_expected = (addr != 0 && addr != 4) || (wr && addr == 4);
        // 1. 下降沿摆好请求，避免与外设的上升沿处理发生竞争。
        @(negedge clk);
        psel = 1; penable = 0; pwrite = wr; paddr = addr; pwdata = value;
        @(posedge clk);
        // 等非阻塞赋值更新后再检查。这里的 #1 是测试安排，不是协议要求。
        #1;
        // 白盒检查内部存储：准备阶段不能提前写，但不拿内部值生成 expected。
        check(dut.data_reg === expected, "no setup write");
        // 2. 下一下降沿进入访问阶段，地址、方向和写数据保持不变。
        @(negedge clk);
        penable = 1;
        waits = 0;
        // 3. 每个上升沿检查就绪；此处先采样，再等电路更新内部状态。
        forever begin
            @(posedge clk);
            if (pready === 1'b1) begin
                // 完成不等于成功：还要比较错误响应。
                check(pslverr === error_expected, "error response");
                if (!wr) begin
                    // 读操作分别检查：错误读返回 0、标识返回 1、DATA 返回期望值。
                    // === 严格比较所有位，包括四态仿真中的 X/Z。
                    if (error_expected) check(prdata === 32'h0, "error read zero");
                    else if (addr == 4) check(prdata === 32'h1, "ID read");
                    else check(prdata === expected, "readback");
                end
                // 只有成功完成的合法写，才改变测试侧的正确答案。
                if (wr && !error_expected) expected = value;
                transfers++;
                break; // 本次已完成，退出等待循环。
            end
            // 尚未完成：统计等待数，限制等待长度，并检查没有提前修改数据。
            check(pready === 1'b0, "known ready");
            waits++;
            check(waits <= WAIT_CYCLES, "bounded wait");
            #1;
            check(dut.data_reg === expected, "no wait write");
        end
        // 4. 完成后核对等待数，再等非阻塞赋值更新，检查实际存储结果。
        check(waits == WAIT_CYCLES, "exact wait count");
        #1;
        check(dut.data_reg === expected, "commit exactly at completion");
        // 暂不撤销选中；下次调用在下一下降沿进入准备阶段，实现背靠背传输。
    endtask

    // 拉低复位并撤销总线请求；不用等上升沿，寄存器就应该清零。
    task automatic reset_bus;
        @(negedge clk);
        rst_n = 0; psel = 0; penable = 0; expected = 0;
        #1;
        check(dut.data_reg === 32'h0, "asynchronous reset");
        check(pready === 1'b0 && pslverr === 1'b0, "reset response");
        repeat (2) @(negedge clk); // 保持复位两周期后，在下降沿解除。
        rst_n = 1;
    endtask

    // 主测试流程：顺序执行，某项失败立即停止。
    initial begin
        // 带 +wave 运行时保存 VCD（Value Change Dump，信号变化记录）波形。
        if ($test$plusargs("wave")) begin
            $dumpfile("apb_regs.vcd");
            $dumpvars(0, apb_regs_tb);
        end
        // 场景一：复位后 DATA=0，固定标识 ID=1。
        reset_bus();
        transfer(0, 0, 0);
        transfer(0, 4, 0);
        // 场景二：不同数据写入后读回，检查数据内容。
        transfer(1, 0, 32'h2a);
        transfer(0, 0, 0);
        transfer(1, 0, 32'hffffffff);
        transfer(0, 0, 0);
        transfer(1, 0, 32'ha5a55a5a);
        transfer(0, 0, 0);
        // 场景三：写只读地址应报错，ID 和原 DATA 都不能被改坏。
        transfer(1, 4, 32'h12345678);
        transfer(0, 4, 0);
        transfer(0, 0, 0);
        // 场景四：非法地址 08、不对齐地址 01，读写都应报错。
        transfer(1, 8, 32'hdeadbeef);
        transfer(0, 8, 0);
        transfer(1, 1, 32'h55);
        transfer(0, 1, 0);
        transfer(0, 0, 0);
        // 场景五：已有非零数据后复位，读回应为 0。
        reset_bus();
        transfer(0, 0, 0);

        // 场景六：用复位取消未完成的写 22。
        // 零等待组在准备阶段打断；其他组进入等待访问后打断。
        @(negedge clk);
        psel = 1; penable = 0; pwrite = 1; paddr = 0; pwdata = 32'h22;
        @(posedge clk);
        #1;
        check(dut.data_reg === expected, "pending setup unchanged");
        if (WAIT_CYCLES > 0) begin
            @(negedge clk); penable = 1;
            @(posedge clk);
            check(pready === 1'b0, "pending access not completed");
        end
        // 故意避开上升沿拉低复位，检查异步复位确实立即起作用。
        #2;
        rst_n = 0; psel = 0; penable = 0; expected = 0;
        #1;
        check(dut.data_reg === 0, "cancel pending write");
        repeat (2) @(negedge clk);
        rst_n = 1;
        // 场景七：旧请求未生效，复位后也能正常接受新的读写。
        transfer(0, 0, 0);
        transfer(1, 0, 32'h36);
        transfer(0, 0, 0);
        @(negedge clk); psel = 0; penable = 0;
        // 被复位取消的那笔不算完成；完整跑完应为 20 笔。
        check(transfers == 20, "all transactions exercised");
        $display("APB_PASS wait=%0d transfers=%0d checks=%0d", WAIT_CYCLES, transfers, checks);
        $finish;
    end
    // 独立超时保护：防止测试一直等待，既不结束也不报错。
    initial begin
        #100000;
        $fatal(1, "TIMEOUT");
    end
endmodule
