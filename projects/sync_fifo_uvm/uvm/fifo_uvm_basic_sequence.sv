`ifndef FIFO_UVM_BASIC_SEQUENCE_SV
`define FIFO_UVM_BASIC_SEQUENCE_SV

class fifo_uvm_basic_sequence #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) extends uvm_sequence #(fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH));

    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;
    localparam bit [DATA_WIDTH-1:0] DATA_A5 = DATA_WIDTH'(8'hA5);
    localparam bit [DATA_WIDTH-1:0] DATA_3C = DATA_WIDTH'(8'h3C);
    localparam bit [DATA_WIDTH-1:0] DATA_7E = DATA_WIDTH'(8'h7E);
    localparam int EXPECTED_ITEMS = 5;

    `uvm_object_param_utils(fifo_uvm_basic_sequence #(DATA_WIDTH, DEPTH))

    int unsigned produced_count;

    function new(string name = "fifo_uvm_basic_sequence");
        super.new(name);
        produced_count = 0;
    endfunction

    virtual task body();
        produced_count = 0;

        send_request(1'b1, DATA_A5, 1'b0, "write_a5");
        send_request(1'b1, DATA_3C, 1'b0, "write_3c");
        send_request(1'b0, '0,      1'b1, "read_1");
        send_request(1'b1, DATA_7E, 1'b1, "write_read_7e");
        send_request(1'b0, '0,      1'b1, "read_2");

        if (produced_count != EXPECTED_ITEMS) begin
            `uvm_fatal("FIFO_SEQ_BODY_COUNT",
                       $sformatf("sequence expected %0d completed items, got %0d",
                                 EXPECTED_ITEMS, produced_count))
        end
    endtask

    virtual task send_request(bit wr_en,
                              bit [DATA_WIDTH-1:0] wr_data,
                              bit rd_en,
                              string item_name);
        item_t request;

        request = item_t::type_id::create(item_name);
        if (request == null) begin
            `uvm_fatal("FIFO_SEQ_FACTORY", "factory returned a null sequence item")
        end

        start_item(request);

        request.transaction_id = {32'b0, produced_count} + 64'd1;
        request.wr_en           = wr_en;
        request.wr_data         = wr_data;
        request.rd_en           = rd_en;

        finish_item(request);
        produced_count++;
    endtask

endclass

`endif
