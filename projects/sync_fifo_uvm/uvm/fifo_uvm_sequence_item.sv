`ifndef FIFO_UVM_SEQUENCE_ITEM_SV
`define FIFO_UVM_SEQUENCE_ITEM_SV

class fifo_uvm_sequence_item #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) extends uvm_sequence_item;

    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);
    longint unsigned transaction_id;
    rand bit                  wr_en;
    rand bit [DATA_WIDTH-1:0] wr_data;
    rand bit                  rd_en;
    logic [DATA_WIDTH-1:0]     rd_data;
    logic                      empty;
    logic                      full;
    logic [COUNT_WIDTH-1:0]    data_count;
    bit                        sampled;

    constraint active_operation_c {
        wr_en || rd_en;
    }

    constraint operation_mix_c {
        {wr_en, rd_en} dist {
            2'b01 := 4,
            2'b10 := 4,
            2'b11 := 2
        };
    }

    /* verilator lint_off WIDTHTRUNC */
    /* verilator lint_off WIDTHEXPAND */
    `uvm_object_param_utils_begin(fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH))
        `uvm_field_int(transaction_id, UVM_ALL_ON)
        `uvm_field_int(wr_en,          UVM_ALL_ON)
        `uvm_field_int(wr_data,        UVM_ALL_ON)
        `uvm_field_int(rd_en,          UVM_ALL_ON)
        `uvm_field_int(rd_data,        UVM_ALL_ON)
        `uvm_field_int(empty,          UVM_ALL_ON)
        `uvm_field_int(full,           UVM_ALL_ON)
        `uvm_field_int(data_count,     UVM_ALL_ON)
        `uvm_field_int(sampled,        UVM_ALL_ON)
    `uvm_object_utils_end
    /* verilator lint_on WIDTHEXPAND */
    /* verilator lint_on WIDTHTRUNC */

    function new(string name = "fifo_uvm_sequence_item");
        super.new(name);

        transaction_id = 0;
        wr_en           = 1'b0;
        wr_data         = '0;
        rd_en           = 1'b0;
        rd_data         = '0;
        empty           = 1'b0;
        full            = 1'b0;
        data_count      = '0;
        sampled         = 1'b0;
    endfunction

    function string operation_name();
        case ({wr_en, rd_en})
            2'b00: return "IDLE";
            2'b01: return "READ";
            2'b10: return "WRITE";
            2'b11: return "WRITE_AND_READ";
            default: return "UNKNOWN";
        endcase
    endfunction

endclass

`endif
