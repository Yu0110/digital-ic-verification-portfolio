`ifndef FIFO_UVM_COVERAGE_SEQUENCE_SV
`define FIFO_UVM_COVERAGE_SEQUENCE_SV

// 定向覆盖序列：以最少事务命中读、写、同时读写与空/中间/满状态交叉。
class fifo_uvm_coverage_sequence #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) extends fifo_uvm_basic_sequence #(DATA_WIDTH, DEPTH);

    `uvm_object_param_utils(fifo_uvm_coverage_sequence #(DATA_WIDTH, DEPTH))

    function new(string name = "fifo_uvm_coverage_sequence");
        super.new(name);
    endfunction

    virtual task body();
        int unsigned index;

        produced_count = 0;

        // 先覆盖空状态操作，再逐步填满并覆盖满状态操作，最后排空。
        send_request(1'b0, '0,                    1'b1, "read_empty");
        send_request(1'b1, DATA_WIDTH'(8'hA0),   1'b1, "write_read_empty");

        send_request(1'b0, '0,                    1'b1, "read_middle_to_empty");

        send_request(1'b1, DATA_WIDTH'(8'h10),   1'b0, "write_empty");

        send_request(1'b1, DATA_WIDTH'(8'h20),   1'b1, "write_read_middle");

        send_request(1'b1, DATA_WIDTH'(8'h30),   1'b0, "write_middle");
        for (index = 2; index < DEPTH; index++) begin
            send_request(1'b1,
                         DATA_WIDTH'(8'h40 + index),
                         1'b0,
                         $sformatf("fill_to_full_%0d", index));
        end

        send_request(1'b1, DATA_WIDTH'(8'hEE),   1'b0, "write_full");
        send_request(1'b1, DATA_WIDTH'(8'hF0),   1'b1, "write_read_full");

        send_request(1'b1, DATA_WIDTH'(8'hF1),   1'b0, "refill_to_full");
        send_request(1'b0, '0,                    1'b1, "read_full");

        for (index = 0; index < DEPTH; index++) begin
            send_request(1'b0, '0, 1'b1, $sformatf("drain_%0d", index));
        end
    endtask

endclass

`endif
