`timescale 1ns/1ps

// 完整 UVM 仿真顶层：实例化接口、DUT、SVA，并把虚接口注入测试环境。
module fifo_uvm_smoke_tb;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;
    logic clk;

    import uvm_pkg::*;
    import fifo_uvm_pkg::*;

    fifo_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) fifo_bus (
        .clk(clk)
    );

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk        (fifo_bus.clk),
        .rst_n      (fifo_bus.rst_n),
        .wr_en      (fifo_bus.wr_en),
        .wr_data    (fifo_bus.wr_data),
        .rd_en      (fifo_bus.rd_en),
        .rd_data    (fifo_bus.rd_data),
        .empty      (fifo_bus.empty),
        .full       (fifo_bus.full),
        .data_count (fifo_bus.data_count)
    );

    fifo_sva_checker #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) sva_checker (
        .clk        (fifo_bus.clk),
        .rst_n      (fifo_bus.rst_n),
        .wr_en      (fifo_bus.wr_en),
        .rd_en      (fifo_bus.rd_en),
        .rd_data    (fifo_bus.rd_data),
        .empty      (fifo_bus.empty),
        .full       (fifo_bus.full),
        .data_count (fifo_bus.data_count)
    );

    always #5ns clk = ~clk;

    initial begin : simulation_watchdog
        #10us;
        $fatal(1, "UVM simulation timeout after 10 us");
    end

    initial begin
        clk              = 1'b0;
        fifo_bus.rst_n   = 1'b1;
        fifo_bus.wr_en   = 1'b0;
        fifo_bus.wr_data = '0;
        fifo_bus.rd_en   = 1'b0;

        uvm_config_db #(virtual fifo_if #(DATA_WIDTH, DEPTH))::set(
            null,
            "uvm_test_top*",
            "vif",
            fifo_bus
        );

        run_test();

        sva_checker.report();
        if ((sva_checker.assertion_failure_count != 0) ||
            (sva_checker.property_failure_count() !=
             sva_checker.assertion_failure_count)) begin
            $fatal(1,
                   "UVM SVA check failed: failures=%0d failure_sum=%0d",
                   sva_checker.assertion_failure_count,
                   sva_checker.property_failure_count());
        end

        $display("UVM SVA CHECK PASS: failures=0 all_exercised=%0b",
                 sva_checker.all_properties_exercised());

        $display("UVM TEST HARNESS PASS: selected test completed all phases");
        $finish;
    end

endmodule
