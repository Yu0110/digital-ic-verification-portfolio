class fifo_transaction #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
);

    localparam int COUNT_WIDTH = (DEPTH >= 1) ? $clog2(DEPTH + 1) : 1;
    longint unsigned transaction_id;
    rand bit wr_en;
    rand bit [DATA_WIDTH-1:0] wr_data;
    rand bit rd_en;

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

    logic [DATA_WIDTH-1:0] rd_data;
    logic                  empty;
    logic                  full;
    logic [COUNT_WIDTH-1:0] data_count;
    bit sampled;

    function new();
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

    virtual function string type_name();
        return "fifo_transaction";
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

    virtual function void print(input string label = "TX");
        $display(
            "%0s id=%0d op=%0s | request: wr_en=%b wr_data=0x%0h rd_en=%b | response: sampled=%b rd_data=0x%0h empty=%b full=%b count=%0d",
            label,
            transaction_id,
            operation_name(),
            wr_en,
            wr_data,
            rd_en,
            sampled,
            rd_data,
            empty,
            full,
            data_count
        );
    endfunction

endclass
