`timescale 1ns/1ps

module sync_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         wr_en,
    input  logic [DATA_WIDTH-1:0]        wr_data,
    input  logic                         rd_en,
    output logic [DATA_WIDTH-1:0]        rd_data,
    output logic                         empty,
    output logic                         full,
    output logic [$clog2(DEPTH + 1)-1:0] data_count
);

    // The fallback width keeps invalid configurations elaboratable long enough
    // for the parameter checks below to issue a useful diagnostic.
    localparam int PTR_WIDTH   = (DEPTH >= 2) ? $clog2(DEPTH) : 1;
    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);
    localparam logic [PTR_WIDTH-1:0]   LAST_ADDR   = PTR_WIDTH'(DEPTH - 1);
    localparam logic [COUNT_WIDTH-1:0] DEPTH_COUNT = COUNT_WIDTH'(DEPTH);
    logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    logic [PTR_WIDTH-1:0]  wr_ptr;
    logic [PTR_WIDTH-1:0]  rd_ptr;
    logic                  write_accept;
    logic                  read_accept;

`ifndef SYNTHESIS
    initial begin : check_parameters
        if (DATA_WIDTH <= 0) begin
            $fatal(1, "sync_fifo: DATA_WIDTH must be greater than 0");
        end
        if (DEPTH < 2) begin
            $fatal(1, "sync_fifo: DEPTH must be at least 2");
        end
    end
`endif

    always_comb begin
        empty = (data_count == '0);
        full  = (data_count == DEPTH_COUNT);
    end

    always_comb begin
        write_accept = wr_en && !full;
        read_accept  = rd_en && !empty;
    end

    // Explicit wrap is required when DEPTH is not a power of two.
    function automatic logic [PTR_WIDTH-1:0] next_ptr(
        input logic [PTR_WIDTH-1:0] current_ptr
    );
        if (current_ptr == LAST_ADDR) begin
`ifdef FIFO_INJECT_BUG_002
            next_ptr = current_ptr + 1'b1;
`else
            next_ptr = '0;
`endif
        end else begin
            next_ptr = current_ptr + 1'b1;
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr     <= '0;
            rd_ptr     <= '0;
            data_count <= '0;
            rd_data    <= '0;
            // Memory is intentionally not reset; count and pointers define validity.
        end else begin
            if (write_accept) begin
                memory[wr_ptr] <= wr_data;
                wr_ptr         <= next_ptr(wr_ptr);
            end
`ifdef FIFO_INJECT_BUG_003
            else if (wr_en && full) begin
                memory[wr_ptr] <= wr_data;
            end
`endif

            if (read_accept) begin
                rd_data <= memory[rd_ptr];
                rd_ptr  <= next_ptr(rd_ptr);
            end

            case ({write_accept, read_accept})
                2'b10: data_count <= data_count + 1'b1;
                2'b01: data_count <= data_count - 1'b1;
                2'b11: begin
`ifdef FIFO_INJECT_BUG_001
                    data_count <= data_count + 1'b1;
`else
                    data_count <= data_count;
`endif
                end
                default: data_count <= data_count;
            endcase
        end
    end

endmodule
