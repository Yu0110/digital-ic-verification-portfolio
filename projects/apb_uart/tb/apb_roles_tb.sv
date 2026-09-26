`timescale 1ns/1ps
// 职责拆分入门版：先用任务和独立进程分工，不引入 class 或 UVM。
module apb_roles_tb;
    parameter int unsigned WAIT_CYCLES = 0;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0;
    logic psel = 0, penable = 0, pwrite = 0;
    logic [7:0] paddr = 0;
    logic [31:0] pwdata = 0;
    wire [31:0] prdata;
    wire pready, pslverr;

    // 协议检查与记分板并行：一个检查过程，另一个检查完成结果。
    apb_protocol_checker protocol_i (
        .clk, .rst_n, .psel, .penable, .pwrite, .pready, .paddr, .pwdata
    );

    apb_regs #(.WAIT_CYCLES(WAIT_CYCLES)) dut (
        .pclk(clk), .presetn(rst_n), .psel, .penable, .pwrite,
        .paddr, .pwdata, .prdata, .pready, .pslverr
    );

    // 一份总线快照，把实际观察到的请求和响应放在一起。
    typedef struct packed {
        logic wr;
        logic [7:0] addr;
        logic [31:0] wdata, rdata;
        logic error;
    } observation_t;
    observation_t observed;
    logic [31:0] expected = 0;
    int received = 0;
    bit corrupt_read;

    // 计划请求只包含输入，不包含实际响应；与监视器的观察记录分开保存。
    typedef struct packed {
        logic wr;
        logic [7:0] addr;
        logic [31:0] data;
    } request_t;
    request_t pending[$]; // 等待被总线观察确认的请求，先进先出。
    int planned = 0, matched = 0;
    string request_fault;
    int random_count = 0;
    int unsigned seed = 1;
    int unsigned seed_state, seed_dummy;
    bit coverage_enabled, close_coverage;
    int expected_count;
    // 8 个方向×地址类别格子，加上合法 DATA 写的 3 种数据类型，共 11 格。
    // 这是显式计数的功能覆盖模型，不是代码覆盖率或 covergroup。
    int access_hits[2][4];
    int data_hits[3];

    task automatic sample_coverage(input observation_t item);
        int kind;
        if (item.addr == 0) kind = 0;
        else if (item.addr == 4) kind = 1;
        else if (item.addr[1:0] == 0) kind = 2;
        else kind = 3;
        access_hits[item.wr][kind]++;
        if (item.wr && item.addr == 0) begin
            if (item.wdata == 0) data_hits[0]++;
            else if (item.wdata == 32'hffffffff) data_hits[1]++;
            else data_hits[2]++;
        end
    endtask

    task automatic report_coverage(input bit enforce);
        int hit;
        hit = 0;
        for (int wr = 0; wr < 2; wr++)
            for (int kind = 0; kind < 4; kind++) begin
                $display("COV_ACCESS wr=%0d kind=%0d hits=%0d", wr, kind, access_hits[wr][kind]);
                if (access_hits[wr][kind] > 0) hit++;
            end
        for (int kind = 0; kind < 3; kind++) begin
            $display("COV_DATA kind=%0d hits=%0d", kind, data_hits[kind]);
            if (data_hits[kind] > 0) hit++;
        end
        $display("COVERAGE hit=%0d total=11", hit);
        if (enforce && hit != 11) $fatal(1, "COVERAGE_GAP hit=%0d total=11", hit);
    endtask

    // 内建伪随机函数只在主激励进程使用；固定种子在相同工具环境下可重放。
    task automatic random_requests;
        bit wr;
        logic [7:0] addr;
        logic [31:0] value;
        for (int i = 0; i < random_count; i++) begin
            wr = 1'($urandom_range(1, 0));
            case ($urandom_range(3, 0))
                0: addr = 0;
                1: addr = 4;
                2: addr = 8'(4 * $urandom_range(63, 2));
                3: addr = 8'(4 * $urandom_range(63, 0) + $urandom_range(3, 1));
            endcase
            case ($urandom_range(2, 0))
                0: value = 0;
                1: value = 32'hffffffff;
                2: value = $urandom;
            endcase
            $display("RANDOM_REQ index=%0d wr=%b addr=%h data=%h", i, wr, addr, value);
            submit(wr, addr, value);
        end
    endtask

    // 随机之后用 10 笔定向请求补齐覆盖，并读回最后一次写入。
    // 日志先报告补齐前覆盖，不能把定向贡献说成纯随机覆盖成果。
    task automatic close_coverage_requests;
        logic [7:0] addr;
        for (int kind = 0; kind < 4; kind++) begin
            case (kind)
                0: addr = 0;
                1: addr = 4;
                2: addr = 8;
                3: addr = 1;
            endcase
            submit(1, addr, 0);
            submit(0, addr, 0);
        end
        submit(1, 0, 32'hffffffff);
        submit(0, 0, 0); // 审计补强：复位前先确认最后的全一写确实生效。
    endtask

    // driver（驱动器）：只发信号和等待完成，不计算 expected，不检查读数据。
    task automatic drive(input bit wr, input logic [7:0] addr,
                         input logic [31:0] value);
        @(negedge clk);
        psel = 1; penable = 0; pwrite = wr; paddr = addr; pwdata = value;
        @(negedge clk);
        penable = 1;
        do @(posedge clk); while (pready !== 1'b1);
        // 等监视器处理完本完成沿，再返回给请求调度任务，避免计数读取竞争。
        #1;
        // 此处不撤销信号；下一笔在下一下降沿进入准备阶段。
    endtask

    // 调度层先保存原始计划，再调用驱动器。故障只影响发送，不修改计划。
    task automatic submit(input bit wr, input logic [7:0] addr,
                          input logic [31:0] value);
        request_t req;
        req.wr = wr; req.addr = addr; req.data = value;
        pending.push_back(req);
        planned++;
        // 故意漏发最后一笔，由收尾检查发现队列中仍有未完成计划。
        if (request_fault == "drop" && planned == 9) return;
        if (planned == 1 && request_fault == "address")
            drive(wr, 8'h04, value);
        else if (planned == 1 && request_fault == "direction")
            drive(!wr, addr, value);
        else if (planned == 1 && request_fault == "data")
            drive(wr, addr, value ^ 32'h1);
        else
            drive(wr, addr, value);
        // 重发没有对应的新计划，即使它返回的读数据正确也应失败。
        if (request_fault == "duplicate" && planned == 9)
            drive(wr, addr, value);
    endtask

    // 请求匹配先于数据记分板：实际完成的操作必须对应最早的未完成计划。
    task automatic match_request(input observation_t item);
        request_t req;
        if (pending.size() == 0) $fatal(1, "REQUEST_UNEXPECTED");
        req = pending.pop_front();
        if (item.addr !== req.addr)
            $fatal(1, "REQUEST_ADDR actual=%h expected=%h", item.addr, req.addr);
        if (item.wr !== req.wr)
            $fatal(1, "REQUEST_DIR actual=%b expected=%b", item.wr, req.wr);
        // 读操作不比较写数据；非法写也必须与计划的写数据一致。
        if (req.wr && item.wdata !== req.data)
            $fatal(1, "REQUEST_DATA actual=%h expected=%h", item.wdata, req.data);
        matched++;
    endtask

    // scoreboard（记分板）：按规格判断错误响应，再更新或比较期望数据。
    // 只读取已通过请求匹配的快照，不访问 dut.data_reg。
    task automatic score(input observation_t item);
        bit should_error;
        logic [31:0] wanted;
        should_error = (item.addr != 0 && item.addr != 4) ||
                       (item.wr && item.addr == 4);
        if (item.error !== should_error)
            $fatal(1, "SCORE_ERROR_RESPONSE addr=%h", item.addr);
        if (item.wr) begin
            if (!should_error) expected = item.wdata;
        end else begin
            wanted = should_error ? 32'h0 :
                     ((item.addr == 4) ? 32'h1 : expected);
            if (item.rdata !== wanted)
                $fatal(1, "SCORE_READBACK addr=%h actual=%h expected=%h",
                       item.addr, item.rdata, wanted);
        end
        received++;
        // 只有请求匹配和功能比较都通过的完成事务，才计入覆盖。
        sample_coverage(item);
        $display("OBS #%0d wr=%b addr=%h wdata=%h rdata=%h error=%b",
                 received, item.wr, item.addr, item.wdata, item.rdata, item.error);
    endtask

    // monitor（监视器）：独立于驱动流程，每个上升沿观察一次总线。
    // 这里不加 #1：读取的是完成沿的响应，不是电路更新后的新状态。
    // 简化版同步调用记分板；以后才引入邮箱或分析端口解耦。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            expected = 0; // 通知参考模型复位；累计观察笔数不清零。
        end else if (psel && penable && pready) begin
            observed.wr = pwrite;
            observed.addr = paddr;
            observed.wdata = pwdata;
            observed.rdata = prdata;
            observed.error = pslverr;
            // 人为污染一次观察值，验证比较器能否抓错，不是 DUT 的真实缺陷。
            if (corrupt_read && !pwrite && received == 1)
                observed.rdata = prdata ^ 32'h1;
            match_request(observed);
            score(observed);
        end
    end

    initial begin
        corrupt_read = $test$plusargs("corrupt_read");
        coverage_enabled = $test$plusargs("coverage");
        close_coverage = coverage_enabled && !$test$plusargs("no_close");
        if (!$value$plusargs("random_count=%d", random_count)) random_count = 0;
        if (!$value$plusargs("seed=%d", seed)) seed = 1;
        if (random_count < 0 || random_count > 1000) $fatal(1, "BAD_RANDOM_COUNT");
        seed_state = seed;
        seed_dummy = $urandom(seed_state);
        expected_count = 9 + random_count + (close_coverage ? 10 : 0);
        $display("RUN seed=%0d random_count=%0d closure=%b", seed, random_count, close_coverage);
        if (!$value$plusargs("request_fault=%s", request_fault)) request_fault = "none";
        if (request_fault != "none" && request_fault != "address" &&
            request_fault != "direction" && request_fault != "data" &&
            request_fault != "drop" && request_fault != "duplicate")
            $fatal(1, "UNKNOWN_REQUEST_FAULT");
        if (request_fault != "none" && (random_count != 0 || coverage_enabled))
            $fatal(1, "REQUEST_FAULT_REQUIRES_DIRECTED_MODE");
        repeat (2) @(negedge clk);
        rst_n = 1;
        submit(1, 0, 32'h2a);
        submit(0, 0, 0);
        submit(1, 4, 32'h55); // 非法写：报错，但 DATA 保留 2A。
        submit(0, 0, 0);
        submit(0, 4, 0);
        submit(0, 8, 0);     // 非法读：按本项目规格返回错误及 0。
        submit(1, 0, 32'h36);
        submit(0, 0, 0);
        random_requests();
        if (coverage_enabled) begin
            $display("COVERAGE_BEFORE_CLOSURE");
            report_coverage(0);
            if (close_coverage) close_coverage_requests();
        end
        // 本版只在请求之间复位，不允许用复位清队列来掩盖漏发。
        if (pending.size() != 0) $fatal(1, "REQUEST_PENDING_BEFORE_RESET");
        @(negedge clk);
        psel = 0; penable = 0; rst_n = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;
        submit(0, 0, 32'hffffffff); // 读时写数据无意义；检查复位后的 DATA=0。
        @(negedge clk);
        psel = 0; penable = 0;
        // 留一个空闲上升沿，让协议检查器检查最后一笔是否退出访问阶段。
        @(posedge clk); #1;
        if (pending.size() != 0)
            $fatal(1, "REQUEST_MISSING pending=%0d", pending.size());
        if (planned != expected_count || matched != planned || received != planned)
            $fatal(1, "REQUEST_COUNT planned=%0d matched=%0d observed=%0d",
                   planned, matched, received);
        $display("REQUESTS_PASS planned=%0d matched=%0d pending=%0d",
                 planned, matched, pending.size());
        if (coverage_enabled) begin
            $display("COVERAGE_FINAL");
            report_coverage(1);
            $display("RANDOM_PASS seed=%0d wait=%0d random=%0d observed=%0d bins=11/11",
                     seed, WAIT_CYCLES, random_count, received);
        end
        $display("ROLES_PASS wait=%0d observed=%0d", WAIT_CYCLES, received);
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "TIMEOUT");
    end
endmodule
