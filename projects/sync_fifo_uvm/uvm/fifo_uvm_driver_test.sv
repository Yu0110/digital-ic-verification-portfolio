`ifndef FIFO_UVM_DRIVER_TEST_SV
`define FIFO_UVM_DRIVER_TEST_SV

class fifo_uvm_driver_test extends uvm_test;

    localparam int DATA_WIDTH  = 8;
    localparam int DEPTH       = 4;
    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);
    localparam int EXPECTED_ITEMS = 5;
    localparam time EXPECTED_RESET_ASSERT_TIME  = 2ns;
    localparam time EXPECTED_RESET_RELEASE_TIME = 10ns;
    localparam time FIRST_OPERATION_TIME        = 25ns;
    localparam time OPERATION_INTERVAL          = 20ns;
    typedef fifo_uvm_sequencer #(DATA_WIDTH, DEPTH)      sequencer_t;
    typedef fifo_uvm_driver #(DATA_WIDTH, DEPTH)         driver_t;
    typedef fifo_uvm_basic_sequence #(DATA_WIDTH, DEPTH) sequence_t;
    typedef virtual fifo_if #(DATA_WIDTH, DEPTH)         virtual_if_t;

    `uvm_component_utils(fifo_uvm_driver_test)

    sequencer_t  sequencer;
    driver_t     driver;
    virtual_if_t vif;
    int unsigned observed_count;
    time reset_assert_time;
    time reset_release_time;

    function new(string name = "fifo_uvm_driver_test",
                 uvm_component parent = null);
        super.new(name, parent);
        observed_count    = 0;
        reset_assert_time = 0ns;
        reset_release_time = 0ns;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sequencer = sequencer_t::type_id::create("sequencer", this);
        driver    = driver_t::type_id::create("driver", this);

        if (sequencer == null) begin
            `uvm_fatal("FIFO_DRV_COMPONENT_NULL",
                       "factory returned a null sequencer")
        end

        if (driver == null) begin
            `uvm_fatal("FIFO_DRV_COMPONENT_NULL", "factory returned a null driver")
        end

        if (!uvm_config_db #(virtual_if_t)::get(this, "", "vif", vif)) begin
            `uvm_fatal("FIFO_TEST_NO_VIF",
                       "fifo_uvm_driver_test could not get virtual interface 'vif'")
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

    virtual task check_reset_and_operations();
        bit expected_wr_en;
        bit [DATA_WIDTH-1:0] expected_wr_data;
        bit expected_rd_en;
        logic [DATA_WIDTH-1:0] expected_rd_data;
        logic [COUNT_WIDTH-1:0] expected_count;
        logic expected_empty;
        logic expected_full;
        time expected_operation_time;

        @(negedge vif.rst_n);
        reset_assert_time = $time;
        #1ns;

        if ((reset_assert_time != EXPECTED_RESET_ASSERT_TIME) ||
            (vif.wr_en       !== 1'b0) ||
            (vif.wr_data     !== '0)   ||
            (vif.rd_en       !== 1'b0) ||
            (vif.rd_data     !== '0)   ||
            (vif.data_count  !== '0)   ||
            (vif.empty       !== 1'b1) ||
            (vif.full        !== 1'b0)) begin
            `uvm_fatal("FIFO_DRV_RESET_ASSERT",
                       $sformatf("asynchronous reset mismatch at t=%0t: count=%0d empty=%0b full=%0b rd_data=0x%0h",
                                 $time,
                                 vif.data_count,
                                 vif.empty,
                                 vif.full,
                                 vif.rd_data))
        end

        @(posedge vif.rst_n);
        reset_release_time = $time;
        if ((reset_release_time != EXPECTED_RESET_RELEASE_TIME) ||
            (vif.clk !== 1'b0)) begin
            `uvm_fatal("FIFO_DRV_RESET_RELEASE",
                       $sformatf("reset released at t=%0t with clk=%0b",
                                 reset_release_time,
                                 vif.clk))
        end

        for (int unsigned index = 0; index < EXPECTED_ITEMS; index++) begin
            do begin
                @(vif.mon_cb);
            end while ((vif.wr_en === 1'b0) && (vif.rd_en === 1'b0));

            case (index)
                0: begin
                    expected_wr_en   = 1'b1;
                    expected_wr_data = DATA_WIDTH'(8'hA5);
                    expected_rd_en   = 1'b0;
                    expected_rd_data = '0;
                    expected_count   = COUNT_WIDTH'(1);
                    expected_empty   = 1'b0;
                    expected_full    = 1'b0;
                end
                1: begin
                    expected_wr_en   = 1'b1;
                    expected_wr_data = DATA_WIDTH'(8'h3C);
                    expected_rd_en   = 1'b0;
                    expected_rd_data = '0;
                    expected_count   = COUNT_WIDTH'(2);
                    expected_empty   = 1'b0;
                    expected_full    = 1'b0;
                end
                2: begin
                    expected_wr_en   = 1'b0;
                    expected_wr_data = '0;
                    expected_rd_en   = 1'b1;
                    expected_rd_data = DATA_WIDTH'(8'hA5);
                    expected_count   = COUNT_WIDTH'(1);
                    expected_empty   = 1'b0;
                    expected_full    = 1'b0;
                end
                3: begin
                    expected_wr_en   = 1'b1;
                    expected_wr_data = DATA_WIDTH'(8'h7E);
                    expected_rd_en   = 1'b1;
                    expected_rd_data = DATA_WIDTH'(8'h3C);
                    expected_count   = COUNT_WIDTH'(1);
                    expected_empty   = 1'b0;
                    expected_full    = 1'b0;
                end
                4: begin
                    expected_wr_en   = 1'b0;
                    expected_wr_data = '0;
                    expected_rd_en   = 1'b1;
                    expected_rd_data = DATA_WIDTH'(8'h7E);
                    expected_count   = COUNT_WIDTH'(0);
                    expected_empty   = 1'b1;
                    expected_full    = 1'b0;
                end
                default: begin
                    `uvm_fatal("FIFO_DRV_EXTRA", "observed more operations than expected")
                end
            endcase

            expected_operation_time = FIRST_OPERATION_TIME +
                                      (time'(index) * OPERATION_INTERVAL);

            if (($time            != expected_operation_time) ||
                (vif.wr_en        !== expected_wr_en)          ||
                (vif.wr_data      !== expected_wr_data)        ||
                (vif.rd_en        !== expected_rd_en)          ||
                (vif.rd_data      !== expected_rd_data)        ||
                (vif.data_count   !== expected_count)          ||
                (vif.empty        !== expected_empty)          ||
                (vif.full         !== expected_full)) begin
                `uvm_fatal("FIFO_DRV_CYCLE",
                           $sformatf("operation %0d mismatch at t=%0t: req=%0b/%0h/%0b response=%0h/%0d/%0b/%0b",
                                     index + 1,
                                     $time,
                                     vif.wr_en,
                                     vif.wr_data,
                                     vif.rd_en,
                                     vif.rd_data,
                                     vif.data_count,
                                     vif.empty,
                                     vif.full))
            end

            observed_count++;

            @(vif.drv_cb);
            #1ps;
            if ((vif.wr_en   !== 1'b0) ||
                (vif.wr_data !== '0)   ||
                (vif.rd_en   !== 1'b0)) begin
                `uvm_fatal("FIFO_DRV_DEASSERT",
                           $sformatf("operation %0d was not deasserted after one active edge",
                                     index + 1))
            end
        end
    endtask

    virtual task run_phase(uvm_phase phase);
        sequence_t basic_seq;

        phase.raise_objection(this, "FIFO UVM driver integration started");

        basic_seq = sequence_t::type_id::create("basic_seq");
        if (basic_seq == null) begin
            `uvm_fatal("FIFO_DRV_SEQ_NULL", "factory returned a null basic sequence")
        end

        fork
            begin : run_sequence
                basic_seq.start(sequencer);
            end
            begin : observe_driver_and_dut
                check_reset_and_operations();
            end
        join

        if ((basic_seq.produced_count != EXPECTED_ITEMS) ||
            (driver.driven_count     != EXPECTED_ITEMS) ||
            (observed_count          != EXPECTED_ITEMS) ||
            (vif.data_count          !== COUNT_WIDTH'(0)) ||
            (vif.empty               !== 1'b1) ||
            (vif.full                !== 1'b0) ||
            (vif.rd_data             !== DATA_WIDTH'(8'h7E))) begin
            `uvm_fatal("FIFO_DRV_STATE",
                       $sformatf("final mismatch: produced=%0d driven=%0d observed=%0d count=%0d empty=%0b full=%0b rd_data=0x%0h",
                                 basic_seq.produced_count,
                                 driver.driven_count,
                                 observed_count,
                                 vif.data_count,
                                 vif.empty,
                                 vif.full,
                                 vif.rd_data))
        end

        `uvm_info("FIFO_DRIVER_PASS",
                  "UVM DRIVER PASS: reset and 5 one-edge requests matched every DUT state; final FIFO empty with rd_data=0x7E",
                  UVM_NONE)

        phase.drop_objection(this, "FIFO UVM driver integration completed");
    endtask

endclass

`endif
