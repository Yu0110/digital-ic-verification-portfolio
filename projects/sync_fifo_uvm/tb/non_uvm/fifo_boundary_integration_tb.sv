`timescale 1ns/1ps

module fifo_boundary_integration_tb #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
);

    localparam int EXPECTED_TRANSACTIONS = (5 * DEPTH) + 8;
    typedef fifo_transaction #(DATA_WIDTH, DEPTH) tx_t;
    logic clk;

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

    mailbox #(tx_t)                           gen_to_drv;
    mailbox #(tx_t)                           mon_to_scoreboard;
    fifo_generator #(DATA_WIDTH, DEPTH)       generator;
    fifo_driver #(DATA_WIDTH, DEPTH)          driver;
    fifo_monitor #(DATA_WIDTH, DEPTH)         monitor;
    fifo_reference_model #(DATA_WIDTH, DEPTH) reference_model;
    fifo_scoreboard #(DATA_WIDTH, DEPTH)      scoreboard;

    always #5 clk = ~clk;

    initial begin : simulation_watchdog
        #10us;
        $fatal(1,
               "NON-UVM layered simulation timeout after 10 us: DATA_WIDTH=%0d DEPTH=%0d",
               DATA_WIDTH,
               DEPTH);
    end

    initial begin
        clk = 1'b0;

        gen_to_drv        = new();
        mon_to_scoreboard = new();

        generator       = new(gen_to_drv);
        driver          = new(gen_to_drv);
        monitor         = new(mon_to_scoreboard);
        reference_model = new();
        scoreboard      = new(mon_to_scoreboard, reference_model);

        driver.connect_interface(fifo_bus);
        monitor.connect_interface(fifo_bus);

        fork
            generator.run_boundary();
            driver.run(EXPECTED_TRANSACTIONS);
            monitor.run(EXPECTED_TRANSACTIONS);
            scoreboard.run(EXPECTED_TRANSACTIONS);
        join

        @(posedge clk);
        #1;

        if ((generator.sent_count         != EXPECTED_TRANSACTIONS) ||
            (driver.received_count        != EXPECTED_TRANSACTIONS) ||
            (monitor.observed_count       != EXPECTED_TRANSACTIONS) ||
            (scoreboard.compared_count    != EXPECTED_TRANSACTIONS) ||
            (scoreboard.pass_count        != EXPECTED_TRANSACTIONS) ||
            (sva_checker.assertion_failure_count != 0) ||
            (!sva_checker.all_properties_exercised()) ||
            (driver.error_count           != 0) ||
            (scoreboard.error_count       != 0) ||
            (reference_model.queue_size() != 0)) begin
            $fatal(1,
                   "BOUNDARY INTEGRATION FAILED DATA_WIDTH=%0d DEPTH=%0d expected=%0d sent=%0d driven=%0d observed=%0d compared=%0d passed=%0d driver_errors=%0d scoreboard_errors=%0d model_queue=%0d",
                   DATA_WIDTH,
                   DEPTH,
                   EXPECTED_TRANSACTIONS,
                   generator.sent_count,
                   driver.received_count,
                   monitor.observed_count,
                   scoreboard.compared_count,
                   scoreboard.pass_count,
                   driver.error_count,
                   scoreboard.error_count,
                   reference_model.queue_size());
        end

        sva_checker.report();

        $display("BOUNDARY INTEGRATION PASS: DATA_WIDTH=%0d DEPTH=%0d transactions=%0d errors=0",
                 DATA_WIDTH,
                 DEPTH,
                 EXPECTED_TRANSACTIONS);
        $finish;
    end

endmodule
