interface fifo_if #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) (
    input logic clk
);

    timeunit 1ns;
    timeprecision 1ps;

    localparam int COUNT_WIDTH = (DEPTH >= 1) ? $clog2(DEPTH + 1) : 1;
    logic                         rst_n;
    logic                         wr_en;
    logic [DATA_WIDTH-1:0]        wr_data;
    logic                         rd_en;
    logic [DATA_WIDTH-1:0]        rd_data;
    logic                         empty;
    logic                         full;
    logic [COUNT_WIDTH-1:0]       data_count;

`ifdef FIFO_ENABLE_CLOCKING_BLOCKS
    // Drive on the falling edge and sample after the rising-edge state update.
    clocking drv_cb @(negedge clk);
        default output #0;
        output wr_en;
        output wr_data;
        output rd_en;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #0;
        input rst_n;
        input wr_en;
        input wr_data;
        input rd_en;
        input rd_data;
        input empty;
        input full;
        input data_count;
    endclocking
`endif

endinterface
