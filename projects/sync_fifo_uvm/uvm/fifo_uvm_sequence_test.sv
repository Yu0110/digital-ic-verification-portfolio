`ifndef FIFO_UVM_SEQUENCE_TEST_SV
`define FIFO_UVM_SEQUENCE_TEST_SV

// 测试专用 sink 模拟 driver，记录 sequencer 交付的每一笔事务。
class fifo_uvm_sequence_sink #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4,
    parameter int EXPECTED_ITEMS = 5,
    parameter time ACK_DELAY = 1ns
) extends uvm_driver #(fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH));

    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;

    `uvm_component_param_utils(fifo_uvm_sequence_sink #(
        DATA_WIDTH,
        DEPTH,
        EXPECTED_ITEMS,
        ACK_DELAY
    ))

    int unsigned received_count;
    int unsigned object_instance_ids[EXPECTED_ITEMS];
    time         acknowledgement_times[EXPECTED_ITEMS];

    function new(string name = "fifo_uvm_sequence_sink",
                 uvm_component parent = null);
        super.new(name, parent);
        received_count = 0;

        for (int unsigned index = 0; index < EXPECTED_ITEMS; index++) begin
            object_instance_ids[index]  = 0;
            acknowledgement_times[index] = 0ns;
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        item_t request;

        repeat (EXPECTED_ITEMS) begin
            seq_item_port.get_next_item(request);

            if (request == null) begin
                `uvm_fatal("FIFO_SEQ_NULL_REQUEST",
                           $sformatf("sink received null item at index %0d",
                                     received_count))
            end

            check_request(request, received_count);

            `uvm_info("FIFO_SEQ_ITEM",
                      $sformatf("received id=%0d op=%0s data=0x%0h",
                                request.transaction_id,
                                request.operation_name(),
                                request.wr_data),
                      UVM_LOW)

            #ACK_DELAY;

            acknowledgement_times[received_count] = $time;
            received_count++;

            seq_item_port.item_done();
        end
    endtask

    virtual function void check_request(item_t request, int unsigned index);
        bit expected_wr_en;
        bit [DATA_WIDTH-1:0] expected_wr_data;
        bit expected_rd_en;
        string expected_name;
        int unsigned current_instance_id;

        if (index >= EXPECTED_ITEMS) begin
            `uvm_fatal("FIFO_SEQ_EXTRA", "sequence produced more items than expected")
        end

        case (index)
            0: begin expected_wr_en = 1'b1; expected_wr_data = DATA_WIDTH'(8'hA5); expected_rd_en = 1'b0; expected_name = "write_a5"; end
            1: begin expected_wr_en = 1'b1; expected_wr_data = DATA_WIDTH'(8'h3C); expected_rd_en = 1'b0; expected_name = "write_3c"; end
            2: begin expected_wr_en = 1'b0; expected_wr_data = '0;                  expected_rd_en = 1'b1; expected_name = "read_1"; end
            3: begin expected_wr_en = 1'b1; expected_wr_data = DATA_WIDTH'(8'h7E); expected_rd_en = 1'b1; expected_name = "write_read_7e"; end
            4: begin expected_wr_en = 1'b0; expected_wr_data = '0;                  expected_rd_en = 1'b1; expected_name = "read_2"; end
            default: begin
                `uvm_fatal("FIFO_SEQ_EXTRA", "sequence produced more than 5 items")
            end
        endcase

        if ((request.transaction_id !== ({32'b0, index} + 64'd1)) ||
            (request.get_name()     != expected_name)               ||
            (request.wr_en          !== expected_wr_en)              ||
            (request.wr_data        !== expected_wr_data)            ||
            (request.rd_en          !== expected_rd_en)              ||
            (request.rd_data        !== '0)                           ||
            (request.empty          !== 1'b0)                         ||
            (request.full           !== 1'b0)                         ||
            (request.data_count     !== '0)                           ||
            (request.sampled        !== 1'b0)) begin
            `uvm_fatal("FIFO_SEQ_ORDER",
                       $sformatf("item %0d mismatch: name=%0s id=%0d wr_en=%0b wr_data=0x%0h rd_en=%0b",
                                 index + 1,
                                 request.get_name(),
                                 request.transaction_id,
                                 request.wr_en,
                                 request.wr_data,
                                 request.rd_en))
        end

        current_instance_id = request.get_inst_id();
        for (int unsigned previous = 0; previous < index; previous++) begin
            if (current_instance_id == object_instance_ids[previous]) begin
                `uvm_fatal("FIFO_SEQ_OBJECT_REUSE",
                           $sformatf("items %0d and %0d reused object instance id %0d",
                                     previous + 1,
                                     index + 1,
                                     current_instance_id))
            end
        end
        object_instance_ids[index] = current_instance_id;
    endfunction

endclass

// Sequence 单元测试：验证五笔事务的数量、顺序、字段和握手延时。
class fifo_uvm_sequence_test extends uvm_test;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;
    localparam int EXPECTED_ITEMS = 5;
    localparam time ITEM_ACK_DELAY = 1ns;
    typedef fifo_uvm_sequencer #(DATA_WIDTH, DEPTH)      sequencer_t;
    typedef fifo_uvm_sequence_sink #(
        DATA_WIDTH,
        DEPTH,
        EXPECTED_ITEMS,
        ITEM_ACK_DELAY
    ) sink_t;
    typedef fifo_uvm_basic_sequence #(DATA_WIDTH, DEPTH) sequence_t;

    `uvm_component_utils(fifo_uvm_sequence_test)

    sequencer_t sequencer;
    sink_t      sink;

    function new(string name = "fifo_uvm_sequence_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sequencer = sequencer_t::type_id::create("sequencer", this);
        sink      = sink_t::type_id::create("sink", this);

        if (sequencer == null) begin
            `uvm_fatal("FIFO_SEQ_NULL_COMPONENT",
                       "factory returned a null sequencer")
        end

        if (sink == null) begin
            `uvm_fatal("FIFO_SEQ_NULL_COMPONENT", "factory returned a null sink")
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        sink.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
        sequence_t basic_seq;
        time sequence_start_time;
        time sequence_finish_time;
        time expected_ack_time;

        phase.raise_objection(this, "FIFO UVM sequence test started");

        basic_seq = sequence_t::type_id::create("basic_seq");
        if (basic_seq == null) begin
            `uvm_fatal("FIFO_SEQ_NULL", "factory returned a null sequence")
        end

        sequence_start_time = $time;
        basic_seq.start(sequencer);
        sequence_finish_time = $time;

        if ((basic_seq.produced_count != EXPECTED_ITEMS) ||
            (sink.received_count      != EXPECTED_ITEMS)) begin
            `uvm_fatal("FIFO_SEQ_COUNT",
                       $sformatf("expected %0d produced/received, got %0d/%0d",
                                 EXPECTED_ITEMS,
                                 basic_seq.produced_count,
                                 sink.received_count))
        end

        if ((sequence_finish_time - sequence_start_time) !=
            (time'(EXPECTED_ITEMS) * ITEM_ACK_DELAY)) begin
            `uvm_fatal("FIFO_SEQ_BLOCKING_TIME",
                       $sformatf("sequence elapsed %0t, expected %0t",
                                 sequence_finish_time - sequence_start_time,
                                 time'(EXPECTED_ITEMS) * ITEM_ACK_DELAY))
        end

        for (int unsigned index = 0; index < EXPECTED_ITEMS; index++) begin
            expected_ack_time = sequence_start_time +
                                ((time'(index) + time'(1)) * ITEM_ACK_DELAY);
            if (sink.acknowledgement_times[index] != expected_ack_time) begin
                `uvm_fatal("FIFO_SEQ_ACK_TIME",
                           $sformatf("item %0d ack at %0t, expected %0t",
                                     index + 1,
                                     sink.acknowledgement_times[index],
                                     expected_ack_time))
            end
        end

        `uvm_info("FIFO_SEQUENCE_PASS",
                  "UVM SEQUENCE PASS: 5 unique ordered items completed 1 ns delayed sequence/sequencer handshakes",
                  UVM_NONE)

        phase.drop_objection(this, "FIFO UVM sequence test completed");
    endtask

endclass

`endif
