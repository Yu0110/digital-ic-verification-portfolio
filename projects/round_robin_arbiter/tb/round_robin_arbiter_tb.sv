`timescale 1ns/1ps

// 黑盒自检测试平台：预期结果只由规格模型计算，不读取 DUT 内部状态。
module round_robin_arbiter_tb;

    localparam int unsigned REQUESTERS = 4;

    logic       clk;
    logic       rst_n;
    logic [3:0] req;
    logic [3:0] grant;
    logic [3:0] last_sampled_grant;

    logic [1:0] model_ptr;
    int unsigned error_count;
    int unsigned comparison_count;
    int unsigned reset_scenarios;
    int unsigned exhaustive_scenarios;
    int unsigned next_state_probes;
    int unsigned fairness_scenarios;
    int unsigned setup_cycles;

    round_robin_arbiter dut (
        .clk   (clk),
        .rst_n (rst_n),
        .req   (req),
        .grant (grant)
    );

`ifdef ARB_ENABLE_SVA
    // SVA = SystemVerilog Assertions，SystemVerilog 断言。
    round_robin_arbiter_sva sva_checker (
        .clk   (clk),
        .rst_n (rst_n),
        .req   (req),
        .grant (grant)
    );
`endif

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // 独立参考模型从指定起点循环搜索，不复用 DUT 的 case 分支。
    function automatic logic [3:0] reference_grant (
        input logic [3:0] request,
        input logic [1:0] start_ptr
    );
        logic found;
        int unsigned offset;
        logic [1:0] index;
        begin
            reference_grant = 4'b0000;
            found           = 1'b0;

            for (offset = 0; offset < REQUESTERS; offset = offset + 1) begin
                // 两位加法自然丢弃进位，等价于对四个请求者执行模 4 回卷。
                index = start_ptr[1:0] + offset[1:0];
                if (!found && request[index]) begin
                    reference_grant[index] = 1'b1;
                    found                  = 1'b1;
                end
            end
        end
    endfunction

    function automatic logic [1:0] reference_next_ptr (
        input logic [3:0] selected,
        input logic [1:0] current_ptr
    );
        int unsigned index;
        begin
            reference_next_ptr = current_ptr;
            for (index = 0; index < REQUESTERS; index = index + 1) begin
                if (selected[index]) begin
                    reference_next_ptr = index[1:0] + 2'd1;
                end
            end
        end
    endfunction

    function automatic int unsigned count_ones (input logic [3:0] value);
        int unsigned index;
        begin
            count_ones = 0;
            for (index = 0; index < REQUESTERS; index = index + 1) begin
                count_ones = count_ones + value[index];
            end
        end
    endfunction

    task automatic record_failure (
        input string check_name,
        input logic [3:0] expected_grant
    );
        begin
            error_count = error_count + 1;
            $display(
                "ERROR [%s] req=%b model_ptr=%0d expected=%b actual=%b time=%0t",
                check_name,
                req,
                model_ptr,
                expected_grant,
                grant,
                $time
            );
        end
    endtask

    // 每个周期同时检查功能结果和三个接口不变量。
    task automatic drive_and_check (
        input logic [3:0] request,
        input string phase
    );
        logic [3:0] expected_grant;
        logic [1:0] expected_next_ptr;
        begin
            @(negedge clk);
            req = request;
            #1;

            last_sampled_grant = grant;
            expected_grant    = reference_grant(request, model_ptr);
            expected_next_ptr = reference_next_ptr(expected_grant, model_ptr);

            comparison_count = comparison_count + 1;
            if (grant !== expected_grant) begin
                record_failure({phase, ": grant mismatch"}, expected_grant);
            end

            comparison_count = comparison_count + 1;
            if ((grant != 4'b0000) &&
                ((grant & (grant - 4'b0001)) != 4'b0000)) begin
                record_failure({phase, ": grant is not one-hot-or-zero"}, expected_grant);
            end

            comparison_count = comparison_count + 1;
            if ((grant & ~request) != 4'b0000) begin
                record_failure({phase, ": grant without request"}, expected_grant);
            end

            comparison_count = comparison_count + 1;
            if (((request == 4'b0000) && (grant != 4'b0000)) ||
                ((request != 4'b0000) && (grant == 4'b0000))) begin
                record_failure({phase, ": request/grant presence mismatch"}, expected_grant);
            end

            // 模型与 DUT 在同一个上升沿推进状态；模型只使用自己的预期授权。
            @(posedge clk);
            model_ptr = expected_next_ptr;
            #1;
        end
    endtask

    // 复位检查覆盖异步生效和跨时钟保持，不读取 DUT 内部轮询指针。
    task automatic apply_and_check_reset (input logic [3:0] request);
        begin
            @(negedge clk);
            req   = request;
            rst_n = 1'b0;
            #1;

            reset_scenarios  = reset_scenarios + 1;
            comparison_count = comparison_count + 1;
            if (grant !== 4'b0000) begin
                record_failure("asynchronous reset grant", 4'b0000);
            end

            @(posedge clk);
            #1;
            comparison_count = comparison_count + 1;
            if (grant !== 4'b0000) begin
                record_failure("reset held across clock edge", 4'b0000);
            end

            model_ptr = 0;
            @(negedge clk);
            req   = 4'b0000;
            rst_n = 1'b1;
            #1;
        end
    endtask

    // 单独请求目标起点的前一位，可从接口上把下一轮起点设置为 target_ptr。
    task automatic position_start_ptr (input int unsigned target_ptr);
        logic [3:0] setup_request;
        begin
            apply_and_check_reset(4'b1111);
            if (target_ptr != 0) begin
                setup_request = 4'b0001 << (target_ptr - 1);
                drive_and_check(setup_request, "start-pointer setup");
                setup_cycles = setup_cycles + 1;
            end
        end
    endtask

    initial begin : regression
        int unsigned start_ptr;
        int unsigned request_value;
        int unsigned round_index;
        int unsigned service_count;
        logic [3:0] active_mask;
        logic [3:0] seen_grants;

        rst_n                 = 1'b1;
        req                   = 4'b0000;
        last_sampled_grant    = 4'b0000;
        model_ptr             = 0;
        error_count           = 0;
        comparison_count      = 0;
        reset_scenarios       = 0;
        exhaustive_scenarios  = 0;
        next_state_probes     = 0;
        fairness_scenarios    = 0;
        setup_cycles          = 0;

        if ($test$plusargs("dump")) begin
            $dumpfile("round_robin_arbiter.vcd");
            $dumpvars(0, round_robin_arbiter_tb);
        end

        // 异步复位与请求向量无关，选择四个代表值单独验证。
        apply_and_check_reset(4'b0000);
        apply_and_check_reset(4'b0001);
        apply_and_check_reset(4'b1010);
        apply_and_check_reset(4'b1111);

        // 穷举 4 个轮询起点与 16 个请求向量，共 64 个状态/输入组合。
        // 每个组合之后使用全请求探针，从外部确认下一状态是否正确。
        for (start_ptr = 0; start_ptr < REQUESTERS; start_ptr = start_ptr + 1) begin
            for (request_value = 0;
                 request_value < (1 << REQUESTERS);
                 request_value = request_value + 1) begin
                position_start_ptr(start_ptr);
                drive_and_check(request_value[3:0], "exhaustive state/request cross");
                exhaustive_scenarios = exhaustive_scenarios + 1;

                drive_and_check(4'b1111, "next-state black-box probe");
                next_state_probes = next_state_probes + 1;
            end
        end

        // 对 15 个非空请求集合和 4 个起点逐一验证公平性。
        // 持续请求 active_mask 中所有请求者后，每人必须恰好得到一次授权。
        for (start_ptr = 0; start_ptr < REQUESTERS; start_ptr = start_ptr + 1) begin
            for (request_value = 1;
                 request_value < (1 << REQUESTERS);
                 request_value = request_value + 1) begin
                active_mask   = request_value[3:0];
                seen_grants   = 4'b0000;
                service_count = count_ones(active_mask);
                position_start_ptr(start_ptr);

                for (round_index = 0;
                     round_index < service_count;
                     round_index = round_index + 1) begin
                    drive_and_check(active_mask, "persistent-request fairness");
                    // 公平性窗口累计 DUT 的实际采样授权，而不是参考模型结果。
                    seen_grants = seen_grants | last_sampled_grant;
                end

                fairness_scenarios = fairness_scenarios + 1;
                comparison_count   = comparison_count + 1;
                if (seen_grants !== active_mask) begin
                    record_failure("fairness window missed requester", active_mask);
                end
            end
        end

        if (error_count != 0) begin
            $fatal(
                1,
                "ARBITER REGRESSION FAILED: %0d errors across %0d comparisons",
                error_count,
                comparison_count
            );
        end

        $display("ARBITER REGRESSION PASS");
        $display("  reset scenarios             : %0d", reset_scenarios);
        $display("  exhaustive state/req cross  : %0d/64", exhaustive_scenarios);
        $display("  next-state black-box probes : %0d/64", next_state_probes);
        $display("  persistent fairness cases   : %0d/60", fairness_scenarios);
        $display("  setup arbitration cycles    : %0d", setup_cycles);
        $display("  automatic comparisons       : %0d", comparison_count);
        $finish;
    end

endmodule
