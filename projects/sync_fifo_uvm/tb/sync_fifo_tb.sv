`timescale 1ns/1ps

module sync_fifo_tb #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
);

    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);
    localparam int WATCHDOG_CYCLES = 200 + (50 * DEPTH);
    localparam int ORDER_TEST_VALUES = (DEPTH < 3) ? DEPTH : 3;
    logic                         clk;
    logic                         rst_n;
    logic                         wr_en;
    logic [DATA_WIDTH-1:0]        wr_data;
    logic                         rd_en;
    logic [DATA_WIDTH-1:0]        rd_data;
    logic                         empty;
    logic                         full;
    logic [COUNT_WIDTH-1:0]       data_count;
    logic [DATA_WIDTH-1:0] expected_queue[$];
    logic [DATA_WIDTH-1:0] expected_rd_data;
    int test_count;
    int check_count;
    int error_count;

    string vcd_file;

    logic assertions_enabled;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .empty(empty),
        .full(full),
        .data_count(data_count)
    );

    always #5 clk = ~clk;

    initial begin : watchdog
        repeat (WATCHDOG_CYCLES) @(posedge clk);
        $fatal(1,
               "sync_fifo_tb timeout after %0d clock cycles (DATA_WIDTH=%0d DEPTH=%0d)",
               WATCHDOG_CYCLES, DATA_WIDTH, DEPTH);
    end

    always @(negedge clk) begin
        if (assertions_enabled && rst_n) begin
            assert (data_count <= COUNT_WIDTH'(DEPTH))
            else begin
                error_count++;
                $display("  ASSERTION ERROR: data_count=%0d exceeds DEPTH=%0d",
                         data_count, DEPTH);
            end

            assert (empty == (data_count == '0))
            else begin
                error_count++;
                $display("  ASSERTION ERROR: empty is inconsistent with data_count");
            end

            assert (full == (data_count == COUNT_WIDTH'(DEPTH)))
            else begin
                error_count++;
                $display("  ASSERTION ERROR: full is inconsistent with data_count");
            end

            assert (!(empty && full))
            else begin
                error_count++;
                $display("  ASSERTION ERROR: empty and full are both high");
            end
        end
    end

    function automatic logic [DATA_WIDTH-1:0] make_data(input int value);
        make_data = DATA_WIDTH'(value);
    endfunction

    function automatic logic [DATA_WIDTH-1:0] make_high_data(input int value);
        logic [DATA_WIDTH-1:0] result;
        begin
            result = DATA_WIDTH'(value);

            result[DATA_WIDTH-1] = 1'b1;

            make_high_data = result;
        end
    endfunction

    task automatic start_test(input string test_name);
        begin
            test_count++;

            $display("\n[%0s]", test_name);
        end
    endtask

    task automatic check_state(input string check_name);
        int expected_size;
        logic expected_empty;
        logic expected_full;
        logic state_ok;
        begin
            expected_size  = expected_queue.size();
            expected_empty = (expected_size == 0);
            expected_full  = (expected_size == DEPTH);

            state_ok       = 1'b1;
            check_count++;

            if (data_count !== COUNT_WIDTH'(expected_size)) begin
                $display("  ERROR %0s: data_count actual=%0d expected=%0d",
                         check_name, data_count, expected_size);
                state_ok = 1'b0;
            end

            if (empty !== expected_empty) begin
                $display("  ERROR %0s: empty actual=%b expected=%b",
                         check_name, empty, expected_empty);
                state_ok = 1'b0;
            end

            if (full !== expected_full) begin
                $display("  ERROR %0s: full actual=%b expected=%b",
                         check_name, full, expected_full);
                state_ok = 1'b0;
            end

            if (rd_data !== expected_rd_data) begin
                $display("  ERROR %0s: rd_data actual=0x%0h expected=0x%0h",
                         check_name, rd_data, expected_rd_data);
                state_ok = 1'b0;
            end

            if (state_ok) begin
                $display("  PASS  %0s: count=%0d empty=%b full=%b rd_data=0x%0h",
                         check_name, data_count, empty, full, rd_data);
            end else begin
                error_count++;
            end
        end
    endtask

    task automatic run_cycle(
        input logic                  request_write,
        input logic [DATA_WIDTH-1:0] write_value,
        input logic                  request_read,
        input string                 cycle_name
    );
        logic expected_write_accept;
        logic expected_read_accept;
        begin
            @(negedge clk);
            wr_en   = request_write;
            wr_data = write_value;
            rd_en   = request_read;

            expected_write_accept = request_write &&
                                    (expected_queue.size() < DEPTH);

            expected_read_accept  = request_read &&
                                    (expected_queue.size() > 0);

            if (expected_read_accept) begin
                expected_rd_data = expected_queue.pop_front();
            end
            if (expected_write_accept) begin
                expected_queue.push_back(write_value);
            end

            @(posedge clk);

            #1;

            check_state(cycle_name);
        end
    endtask

    task automatic apply_async_reset(
        input logic  request_write_during_reset,
        input logic  request_read_during_reset,
        input string reset_name
    );
        begin
            @(negedge clk);
            wr_en   = request_write_during_reset;

            wr_data = make_high_data(int'(8'h5a));
            rd_en   = request_read_during_reset;

            #2;
            rst_n = 1'b0;

            expected_queue.delete();

            expected_rd_data = '0;

            #1;
            check_state({reset_name, " asynchronous assertion"});

            @(posedge clk);
            #1;
            check_state({reset_name, " held active"});

            @(negedge clk);
            wr_en   = 1'b0;
            wr_data = '0;
            rd_en   = 1'b0;
            rst_n   = 1'b1;

            assertions_enabled = 1'b1;
        end
    endtask

    task automatic fill_fifo(input int first_value, input string test_name);
        int index;
        begin
            for (index = 0; index < DEPTH; index++) begin
                run_cycle(1'b1, make_data(first_value + index), 1'b0,
                          $sformatf("%0s write index %0d", test_name, index));
            end
        end
    endtask

    task automatic drain_fifo(input string test_name);
        int index;
        begin
            for (index = 0; index < DEPTH; index++) begin
                run_cycle(1'b0, '0, 1'b1,
                          $sformatf("%0s read index %0d", test_name, index));
            end
        end
    endtask

    initial begin
        int index;

        clk              = 1'b0;

        rst_n            = 1'b1;

        wr_en            = 1'b0;
        wr_data          = '0;
        rd_en            = 1'b0;

        expected_rd_data = '0;

        test_count       = 0;
        check_count      = 0;
        error_count      = 0;

        assertions_enabled = 1'b0;

        if (!$value$plusargs("VCD=%s", vcd_file)) begin
            vcd_file = "build/directed/sync_fifo.vcd";
        end

        $dumpfile(vcd_file);
        $dumpvars(0, sync_fifo_tb);

        start_test("TEST-001/002 asynchronous reset and reset-time requests");
        apply_async_reset(1'b1, 1'b1, "initial reset");

        start_test("TEST-003 single write and read");
        run_cycle(1'b1, make_data(int'(8'h0a)), 1'b0, "write A");
        run_cycle(1'b0, '0, 1'b1, "read A");

        start_test("TEST-004 multiple values preserve FIFO order");

        apply_async_reset(1'b0, 1'b0, "before multiple values");

        for (index = 0; index < ORDER_TEST_VALUES; index++) begin
            run_cycle(1'b1, make_data((index + 1) * 8'h11), 1'b0,
                      $sformatf("ordered write index %0d", index));
        end

        for (index = 0; index < ORDER_TEST_VALUES; index++) begin
            run_cycle(1'b0, '0, 1'b1,
                      $sformatf("ordered read index %0d", index));
        end

        start_test("TEST-005 rejected empty reads hold state and rd_data");
        run_cycle(1'b0, '0, 1'b1, "empty read 1");
        run_cycle(1'b0, '0, 1'b1, "empty read 2");

        start_test("TEST-006/007/008 fill, reject full write, preserve data, drain");
        apply_async_reset(1'b0, 1'b0, "before full test");
        fill_fifo(int'(8'h40), "fill to full");

        run_cycle(1'b1, make_data(int'(8'hee)), 1'b0, "rejected full write E");

        drain_fifo("drain original full contents");

        start_test("TEST-009 normal simultaneous read and write");
        apply_async_reset(1'b0, 1'b0, "before normal simultaneous test");
        run_cycle(1'b1, make_data(int'(8'ha1)), 1'b0, "write A");

        if (DEPTH > 2) begin
            run_cycle(1'b1, make_data(int'(8'hb2)), 1'b0, "write B");
        end

        run_cycle(1'b1, make_data(int'(8'hc3)), 1'b1, "read A and write C");

        if (DEPTH > 2) begin
            run_cycle(1'b0, '0, 1'b1, "read B after simultaneous operation");
        end

        run_cycle(1'b0, '0, 1'b1, "read C after simultaneous operation");

        start_test("TEST-010 empty simultaneous request accepts only write");
        run_cycle(1'b1, make_data(int'(8'h5a)), 1'b1, "empty simultaneous request");
        run_cycle(1'b0, '0, 1'b1, "read value written while empty");

        start_test("TEST-011 full simultaneous request accepts only read");
        apply_async_reset(1'b0, 1'b0, "before full simultaneous test");
        fill_fifo(int'(8'h60), "fill before full simultaneous request");
        run_cycle(1'b1, make_data(int'(8'hef)), 1'b1, "full simultaneous request");

        while (expected_queue.size() > 0) begin
            run_cycle(1'b0, '0, 1'b1, "drain after full simultaneous request");
        end

        start_test("TEST-012/013 single write-pointer and read-pointer wrap");
        apply_async_reset(1'b0, 1'b0, "before single wrap test");
        fill_fifo(int'(8'h70), "initial fill for wrap");
        run_cycle(1'b0, '0, 1'b1, "wrap setup read 0");
        run_cycle(1'b0, '0, 1'b1, "wrap setup read 1");
        run_cycle(1'b1, make_data(int'(8'h7e)), 1'b0, "write after write-pointer wrap 0");
        run_cycle(1'b1, make_data(int'(8'h7f)), 1'b0, "write after write-pointer wrap 1");
        drain_fifo("drain across read-pointer wrap");

        start_test("TEST-014 more than three complete pointer wraps");
        apply_async_reset(1'b0, 1'b0, "before wrap stress");
        run_cycle(1'b1, make_data(1), 1'b0, "seed wrap stress");

        for (index = 2; index <= (3 * DEPTH + 2); index++) begin
            run_cycle(1'b1, make_data(index), 1'b1,
                      $sformatf("wrap stress simultaneous cycle %0d", index));
        end

        run_cycle(1'b0, '0, 1'b1, "drain final wrap stress value");

        start_test("TEST-015 rd_data holds during idle and rejected reads");
        apply_async_reset(1'b0, 1'b0, "before rd_data hold test");
        run_cycle(1'b1, make_data(int'(8'h9a)), 1'b0, "write hold-test value");
        run_cycle(1'b0, '0, 1'b1, "read hold-test value");
        run_cycle(1'b0, '0, 1'b0, "idle hold cycle 1");
        run_cycle(1'b0, '0, 1'b0, "idle hold cycle 2");
        run_cycle(1'b0, '0, 1'b1, "rejected empty read holds rd_data");

        start_test("TEST-016 asynchronous reset from non-empty state");
        run_cycle(1'b1, make_data(int'(8'haa)), 1'b0, "write before non-empty reset A");
        if (DEPTH > 2) begin
            run_cycle(1'b1, make_data(int'(8'hbb)), 1'b0, "write before non-empty reset B");
        end
        apply_async_reset(1'b1, 1'b1, "non-empty reset");

        start_test("TEST-017 asynchronous reset from full state");
        fill_fifo(int'(8'h20), "fill before full reset");
        apply_async_reset(1'b1, 1'b1, "full reset");

        start_test("TEST-018/019 parameterized data width and depth path");
        run_cycle(1'b1, make_high_data(int'(8'h35)), 1'b0, "write high-bit parameter value");
        run_cycle(1'b0, '0, 1'b1, "read high-bit parameter value");

        for (index = 0; index < (DEPTH + 1); index++) begin
            run_cycle(1'b1, make_high_data(index), 1'b0,
                      $sformatf("parameter fill request %0d", index));
        end

        drain_fifo("parameter drain and wrap");

        @(negedge clk);
        wr_en = 1'b0;
        rd_en = 1'b0;

        $display("\n============================================================");
        $display("FIFO DIRECTED REGRESSION SUMMARY");
        $display("DATA_WIDTH=%0d DEPTH=%0d", DATA_WIDTH, DEPTH);
        $display("TEST GROUPS=%0d CHECKS=%0d ERRORS=%0d",
                 test_count, check_count, error_count);

        if (error_count == 0) begin
            $display("ALL DIRECTED TESTS PASSED");
            $display("============================================================");
            $finish;
        end else begin
            $display("DIRECTED TESTS FAILED");
            $display("============================================================");
            $fatal(1, "sync_fifo directed regression failed");
        end
    end

endmodule
