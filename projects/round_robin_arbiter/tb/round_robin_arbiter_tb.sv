// 设置仿真时间单位为 1 ns（nanosecond，纳秒），
// 时间精度为 1 ps（picosecond，皮秒）。
`timescale 1ns/1ps

// round_robin_arbiter_tb 是 testbench（测试平台 / 测试代码）的顶层模块。
module round_robin_arbiter_tb;

    // testbench 产生的输入信号。
    logic       clk;
    logic       rst_n;
    logic [3:0] req;

    // 从 DUT 读取的实际授权结果。
    logic [3:0] grant;

    // DUT = Design Under Test，被测设计。
    // 这里把 testbench 中的信号连接到轮询仲裁器端口。
    round_robin_arbiter dut (
        .clk   (clk),
        .rst_n (rst_n),
        .req   (req),
        .grant (grant)
    );

    // 测试总数和错误总数。
    integer test_count;
    integer error_count;

    // 时钟周期为 10 ns：低电平 5 ns，高电平 5 ns。
    // clk 每经过 5 ns 取反一次，因此上升沿每 10 ns 出现一次。
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // 检查复位行为。
    // 即使复位期间存在请求，grant 也必须为 0000，指针也必须为 0。
    task automatic apply_and_check_reset (
        input logic [3:0] request_during_reset
    );
        begin
            rst_n = 1'b0;
            req   = request_during_reset;

            // 等待 1 ns，让异步复位和组合逻辑完成更新。
            #1;
            test_count = test_count + 1;

            if ((grant !== 4'b0000) ||
                (dut.priority_ptr !== 2'b00)) begin
                error_count = error_count + 1;
                $display(
                    "FAIL %0d RESET: req=%b, grant=%b, priority_ptr=%0d",
                    test_count,
                    req,
                    grant,
                    dut.priority_ptr
                );
            end else begin
                $display(
                    "PASS %0d RESET: req=%b, grant=%b, priority_ptr=%0d",
                    test_count,
                    req,
                    grant,
                    dut.priority_ptr
                );
            end

            // 在下降沿解除复位，避免测试代码恰好在采样上升沿修改复位。
            @(negedge clk);
            req   = 4'b0000;
            rst_n = 1'b1;
            #1;
        end
    endtask

    // 执行并检查一个完整的仲裁周期。
    task automatic run_cycle (
        input logic [3:0] test_req,
        input logic [1:0] expected_current_ptr,
        input logic [3:0] expected_grant,
        input logic [1:0] expected_next_ptr
    );
        begin
            // 在下降沿设置请求，使请求在下一个上升沿之前保持稳定。
            @(negedge clk);
            req = test_req;

            // grant 是组合输出，等待 1 ns 后检查本轮结果。
            #1;
            test_count = test_count + 1;

            // 检查当前指针和授权结果是否符合本测试场景。
            if ((dut.priority_ptr !== expected_current_ptr) ||
                (grant !== expected_grant)) begin
                error_count = error_count + 1;
                $display(
                    "FAIL %0d DATA: req=%b, ptr=%0d, grant=%b, expected_ptr=%0d, expected_grant=%b",
                    test_count,
                    req,
                    dut.priority_ptr,
                    grant,
                    expected_current_ptr,
                    expected_grant
                );
            end

            // one-hot 检查：非零 grant 与 grant-1 做按位与，结果必须为 0。
            // 如果 grant 中同时有两个或更多的 1，这个表达式就会得到非零结果。
            if ((grant != 4'b0000) &&
                ((grant & (grant - 4'b0001)) != 4'b0000)) begin
                error_count = error_count + 1;
                $display(
                    "FAIL %0d ONE-HOT: grant=%b contains multiple active bits",
                    test_count,
                    grant
                );
            end

            // 合法性检查：授权位必须对应一个有效请求位。
            // grant & ~req 非零，表示模块授权了没有提出请求的人。
            if ((grant & ~req) != 4'b0000) begin
                error_count = error_count + 1;
                $display(
                    "FAIL %0d LEGALITY: req=%b, grant=%b",
                    test_count,
                    req,
                    grant
                );
            end

            // 等待上升沿，让 priority_ptr 保存 priority_ptr_next。
            @(posedge clk);
            #1;

            if (dut.priority_ptr !== expected_next_ptr) begin
                error_count = error_count + 1;
                $display(
                    "FAIL %0d POINTER: ptr=%0d, expected_next_ptr=%0d",
                    test_count,
                    dut.priority_ptr,
                    expected_next_ptr
                );
            end else if ((grant === expected_grant) &&
                         (expected_current_ptr === expected_next_ptr)) begin
                // 当前指针和下一指针相同时，grant 在上升沿后不会因指针改变而变化。
                $display(
                    "PASS %0d: req=%b, start_ptr=%0d, grant=%b, next_ptr=%0d",
                    test_count,
                    test_req,
                    expected_current_ptr,
                    expected_grant,
                    expected_next_ptr
                );
            end else begin
                // grant 是组合输出。上升沿更新指针后，它可能立即变成下一轮授权，
                // 因此这里打印测试前保存的 expected_grant，而不再次比较当前 grant。
                $display(
                    "PASS %0d: req=%b, start_ptr=%0d, grant=%b, next_ptr=%0d",
                    test_count,
                    test_req,
                    expected_current_ptr,
                    expected_grant,
                    expected_next_ptr
                );
            end
        end
    endtask

    // 仿真开始时依次运行所有测试场景。
    initial begin
        // 生成 VCD（Value Change Dump，数值变化转储）波形文件。
        $dumpfile("round_robin_arbiter.vcd");
        $dumpvars(0, round_robin_arbiter_tb);

        rst_n       = 1'b0;
        req         = 4'b0000;
        test_count  = 0;
        error_count = 0;

        // 场景 1：复位期间即使所有人请求，也不能产生授权。
        apply_and_check_reset(4'b1111);

        // 场景 2：无人请求时，不授权并保持当前指针 0。
        run_cycle(4'b0000, 2'd0, 4'b0000, 2'd0);

        // 场景 3：依次验证四个单独请求，并检查指针移动。
        run_cycle(4'b0001, 2'd0, 4'b0001, 2'd1);
        run_cycle(4'b0010, 2'd1, 4'b0010, 2'd2);
        run_cycle(4'b0100, 2'd2, 4'b0100, 2'd3);
        run_cycle(4'b1000, 2'd3, 4'b1000, 2'd0);

        // 场景 4：四个请求持续有效，应按 0、1、2、3、0 轮流授权。
        run_cycle(4'b1111, 2'd0, 4'b0001, 2'd1);
        run_cycle(4'b1111, 2'd1, 4'b0010, 2'd2);
        run_cycle(4'b1111, 2'd2, 4'b0100, 2'd3);
        run_cycle(4'b1111, 2'd3, 4'b1000, 2'd0);
        run_cycle(4'b1111, 2'd0, 4'b0001, 2'd1);

        // 场景 5：重新复位，再用请求者 1 把下一轮起点移动到 2。
        apply_and_check_reset(4'b0000);
        run_cycle(4'b0010, 2'd0, 4'b0010, 2'd2);

        // req=1011 且从 2 开始时，应得到请求者 3、0、1、3。
        run_cycle(4'b1011, 2'd2, 4'b1000, 2'd0);
        run_cycle(4'b1011, 2'd0, 4'b0001, 2'd1);
        run_cycle(4'b1011, 2'd1, 4'b0010, 2'd2);
        run_cycle(4'b1011, 2'd2, 4'b1000, 2'd0);

        // 场景 6：先把指针移动到 2，再检查无请求时连续保持。
        apply_and_check_reset(4'b0000);
        run_cycle(4'b0010, 2'd0, 4'b0010, 2'd2);
        run_cycle(4'b0000, 2'd2, 4'b0000, 2'd2);
        run_cycle(4'b0000, 2'd2, 4'b0000, 2'd2);

        // 所有检查结束后，只要 error_count 仍为 0，就表示全部通过。
        if (error_count == 0) begin
            $display("ALL TESTS PASSED: %0d cases", test_count);
        end else begin
            $fatal(
                1,
                "TEST FAILED: %0d errors in %0d cases",
                error_count,
                test_count
            );
        end

        $finish;
    end

endmodule
