`ifndef FIFO_UVM_SCOREBOARD_TEST_SV
`define FIFO_UVM_SCOREBOARD_TEST_SV

// 参考模型单元测试：用手工期望值覆盖空、中间、满和复位后的行为。
class fifo_uvm_reference_model_test extends uvm_test;

    localparam int DATA_WIDTH  = 16;
    localparam int DEPTH       = 5;
    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);
    localparam int EXPECTED_CHECKS = 15;
    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;
    typedef fifo_uvm_reference_model #(DATA_WIDTH, DEPTH) reference_model_t;

    `uvm_component_utils(fifo_uvm_reference_model_test)

    reference_model_t reference_model;
    int unsigned total_check_count;
    int unsigned error_count;

    function new(string name = "fifo_uvm_reference_model_test",
                 uvm_component parent = null);
        super.new(name, parent);
        reference_model  = null;
        total_check_count = 0;
        error_count       = 0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        reference_model = reference_model_t::type_id::create(
            "reference_model"
        );
        if (reference_model == null) begin
            `uvm_fatal("FIFO_REF_TEST_FACTORY",
                       "reference model factory returned a null object")
        end
    endfunction

    function void apply_and_check(
        input bit                      wr_en,
        input bit [DATA_WIDTH-1:0]     wr_data,
        input bit                      rd_en,
        input logic [DATA_WIDTH-1:0]   expected_rd_data,
        input int unsigned             expected_count,
        input logic                    expected_empty,
        input logic                    expected_full,
        input string                   label
    );
        item_t observed_tx;
        item_t expected_tx;
        int unsigned expected_model_step;
        string expected_object_name;
        bit mismatch;

        expected_model_step = reference_model.prediction_count + 1;
        expected_object_name = $sformatf("expected_tx_%0d", expected_model_step);

        observed_tx = item_t::type_id::create(
            $sformatf("model_probe_%0d_%0s", total_check_count + 1, label)
        );
        if (observed_tx == null) begin
            `uvm_fatal("FIFO_REF_TEST_ITEM",
                       "reference model test factory returned a null transaction")
            return;
        end

        observed_tx.transaction_id = {32'b0, total_check_count} + 64'd1;
        observed_tx.wr_en           = wr_en;
        observed_tx.wr_data         = wr_data;
        observed_tx.rd_en           = rd_en;

        observed_tx.rd_data     = ~expected_rd_data;
        observed_tx.data_count  = ~COUNT_WIDTH'(expected_count);
        observed_tx.empty       = ~expected_empty;
        observed_tx.full        = ~expected_full;
        observed_tx.sampled    = 1'b0;

        expected_tx = reference_model.predict(observed_tx);
        if (expected_tx == null) begin
            `uvm_fatal("FIFO_REF_TEST_NULL",
                       "reference model returned a null expected transaction")
            return;
        end

        mismatch =
            (expected_tx.get_name()      != expected_object_name) ||
            (expected_tx.transaction_id  != observed_tx.transaction_id) ||
            (expected_tx.wr_en           != wr_en) ||
            (expected_tx.wr_data         != wr_data) ||
            (expected_tx.rd_en           != rd_en) ||
            (expected_tx.sampled         != 1'b1) ||
            (expected_tx.rd_data         !== expected_rd_data) ||
            (expected_tx.data_count      !== COUNT_WIDTH'(expected_count)) ||
            (expected_tx.empty           !== expected_empty) ||
            (expected_tx.full            !== expected_full) ||
            (reference_model.prediction_count != expected_model_step) ||
            (reference_model.queue_size()      != expected_count) ||
            $isunknown({expected_tx.rd_data,
                        expected_tx.data_count,
                        expected_tx.empty,
                        expected_tx.full});

        if (mismatch) begin
            error_count++;
            `uvm_error("FIFO_REF_TEST_MISMATCH",
                       $sformatf("check=%0d label=%0s | actual prediction: name=%0s rd_data=0x%0h count=%0d empty=%0b full=%0b queue=%0d predictions=%0d | expected: name=%0s rd_data=0x%0h count=%0d empty=%0b full=%0b predictions=%0d",
                                 total_check_count + 1,
                                 label,
                                 expected_tx.get_name(),
                                 expected_tx.rd_data,
                                 expected_tx.data_count,
                                 expected_tx.empty,
                                 expected_tx.full,
                                 reference_model.queue_size(),
                                 reference_model.prediction_count,
                                 expected_object_name,
                                 expected_rd_data,
                                 expected_count,
                                 expected_empty,
                                 expected_full,
                                 expected_model_step))
        end else begin
            `uvm_info("FIFO_REF_TEST_PASS",
                      $sformatf("check=%0d label=%0s rd_data=0x%0h count=%0d empty=%0b full=%0b",
                                total_check_count + 1,
                                label,
                                expected_tx.rd_data,
                                expected_tx.data_count,
                                expected_tx.empty,
                                expected_tx.full),
                      UVM_LOW)
        end

        total_check_count++;
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "FIFO UVM reference model contract test started");

        apply_and_check(0, 16'h0000, 1, 16'h0000, 0, 1, 0, "read_empty");
        apply_and_check(1, 16'hABCD, 1, 16'h0000, 1, 0, 0, "write_read_empty");

        apply_and_check(1, 16'h1111, 0, 16'h0000, 2, 0, 0, "fill_2");
        apply_and_check(1, 16'h2222, 0, 16'h0000, 3, 0, 0, "fill_3");
        apply_and_check(1, 16'h3333, 0, 16'h0000, 4, 0, 0, "fill_4");
        apply_and_check(1, 16'h4444, 0, 16'h0000, 5, 0, 1, "fill_5_full");

        apply_and_check(1, 16'hEEEE, 0, 16'h0000, 5, 0, 1, "write_full");
        apply_and_check(1, 16'hFFFF, 1, 16'hABCD, 4, 0, 0, "write_read_full");

        apply_and_check(1, 16'h5555, 1, 16'h1111, 4, 0, 0, "write_read_middle");

        reference_model.reset_model();
        if ((reference_model.queue_size() != 0) ||
            (reference_model.prediction_count != 0)) begin
            `uvm_fatal("FIFO_REF_TEST_RESET",
                       "reset_model did not clear queue and prediction count")
        end

        apply_and_check(0, 16'h0000, 1, 16'h0000, 0, 1, 0, "read_after_reset");
        apply_and_check(1, 16'hCA01, 0, 16'h0000, 1, 0, 0, "write_ca01");
        apply_and_check(1, 16'hCA02, 0, 16'h0000, 2, 0, 0, "write_ca02");
        apply_and_check(0, 16'h0000, 1, 16'hCA01, 1, 0, 0, "read_ca01");
        apply_and_check(0, 16'h0000, 1, 16'hCA02, 0, 1, 0, "read_ca02");
        apply_and_check(0, 16'h0000, 1, 16'hCA02, 0, 1, 0, "read_empty_holds");

        if ((total_check_count != EXPECTED_CHECKS) ||
            (error_count != 0) ||
            (reference_model.prediction_count != 6) ||
            (reference_model.queue_size() != 0)) begin
            `uvm_fatal("FIFO_REF_TEST_SUMMARY",
                       $sformatf("expected checks=15 errors=0 post-reset predictions=6 queue=0; got checks=%0d errors=%0d predictions=%0d queue=%0d",
                                 total_check_count,
                                 error_count,
                                 reference_model.prediction_count,
                                 reference_model.queue_size()))
            return;
        end

        `uvm_info("FIFO_REFERENCE_MODEL_PASS",
                  "UVM REFERENCE MODEL PASS: 15 independent 16x5 boundary predictions passed with poisoned response inputs and non-empty reset",
                  UVM_NONE)

        phase.drop_objection(this, "FIFO UVM reference model contract test completed");
    endtask

endclass

// 记分板正向测试：人工发送实际事务并确认全部字段比较通过。
class fifo_uvm_scoreboard_test extends uvm_test;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;
    typedef fifo_uvm_sequencer #(DATA_WIDTH, DEPTH)      sequencer_t;
    typedef fifo_uvm_driver #(DATA_WIDTH, DEPTH)         driver_t;
    typedef fifo_uvm_monitor #(DATA_WIDTH, DEPTH)        monitor_t;
    typedef fifo_uvm_scoreboard #(DATA_WIDTH, DEPTH)     scoreboard_t;
    typedef fifo_uvm_basic_sequence #(DATA_WIDTH, DEPTH) sequence_t;

    `uvm_component_utils(fifo_uvm_scoreboard_test)

    sequencer_t  sequencer;
    driver_t     driver;
    monitor_t    monitor;
    scoreboard_t scoreboard;

    function new(string name = "fifo_uvm_scoreboard_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sequencer  = sequencer_t::type_id::create("sequencer", this);
        driver     = driver_t::type_id::create("driver", this);
        monitor    = monitor_t::type_id::create("monitor", this);
        scoreboard = scoreboard_t::type_id::create("scoreboard", this);

        if ((sequencer == null) ||
            (driver == null) ||
            (monitor == null) ||
            (scoreboard == null)) begin
            `uvm_fatal("FIFO_SCB_COMPONENT_NULL",
                       "scoreboard integration factory returned a null component")
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        driver.seq_item_port.connect(sequencer.seq_item_export);

        monitor.observed_ap.connect(scoreboard.analysis_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
        sequence_t basic_seq;

        phase.raise_objection(this, "FIFO UVM scoreboard integration started");

        basic_seq = sequence_t::type_id::create("basic_seq");
        if (basic_seq == null) begin
            `uvm_fatal("FIFO_SCB_SEQ_NULL",
                       "factory returned a null basic sequence")
        end

        if ((monitor.observed_ap.size() != 1) ||
            (scoreboard.reference_model == null)) begin
            `uvm_fatal("FIFO_SCB_HIERARCHY",
                       $sformatf("expected one monitor subscriber and one reference model; subscribers=%0d reference_model_null=%0b",
                                 monitor.observed_ap.size(),
                                 scoreboard.reference_model == null))
            return;
        end

        basic_seq.start(sequencer);

        if ((basic_seq.produced_count             != 5) ||
            (driver.driven_count                  != 5) ||
            (monitor.observed_count               != 5) ||
            (scoreboard.compared_count            != 5) ||
            (scoreboard.pass_count                != 5) ||
            (scoreboard.error_count               != 0) ||
            (scoreboard.field_mismatch_count()    != 0) ||
            (scoreboard.reference_model.prediction_count != 5) ||
            (scoreboard.reference_model.queue_size()      != 0) ||
            (scoreboard.last_actual_tx             == null) ||
            (scoreboard.last_expected_tx           == null) ||
            (scoreboard.last_actual_tx             == scoreboard.last_expected_tx) ||
            (scoreboard.last_actual_tx.transaction_id != 64'd5) ||
            (scoreboard.last_actual_tx.rd_data     !== DATA_WIDTH'(8'h7E)) ||
            (scoreboard.last_actual_tx.data_count  !== '0) ||
            (scoreboard.last_actual_tx.empty       !== 1'b1) ||
            (scoreboard.last_actual_tx.full        !== 1'b0) ||
            (scoreboard.last_expected_tx.get_name() != "expected_tx_5") ||
            (scoreboard.last_expected_tx.rd_data   !== DATA_WIDTH'(8'h7E)) ||
            (scoreboard.last_expected_tx.data_count !== '0) ||
            (scoreboard.last_expected_tx.empty     !== 1'b1) ||
            (scoreboard.last_expected_tx.full      !== 1'b0)) begin
            `uvm_fatal("FIFO_SCB_SUMMARY",
                       $sformatf("expected produced/driven/observed/compared/pass/predicted=5, transaction_errors=0, field_errors=0, queue=0 and final rd_data=7E empty=1; got %0d/%0d/%0d/%0d/%0d/%0d, transaction_errors=%0d, field_errors=%0d, queue=%0d",
                                 basic_seq.produced_count,
                                 driver.driven_count,
                                 monitor.observed_count,
                                 scoreboard.compared_count,
                                 scoreboard.pass_count,
                                 scoreboard.reference_model.prediction_count,
                                 scoreboard.error_count,
                                 scoreboard.field_mismatch_count(),
                                 scoreboard.reference_model.queue_size()))
            return;
        end

        `uvm_info("FIFO_SCOREBOARD_PASS",
                  "UVM SCOREBOARD PASS: 5 observed transactions matched the independent reference model",
                  UVM_NONE)

        phase.drop_objection(this, "FIFO UVM scoreboard integration completed");
    endtask

endclass

// 预期负向测试：故意篡改采样字段，证明记分板能够报告错误。
class fifo_uvm_scoreboard_fault_test extends uvm_test;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;
    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);
    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;
    typedef fifo_uvm_scoreboard #(DATA_WIDTH, DEPTH)     scoreboard_t;

    `uvm_component_utils(fifo_uvm_scoreboard_fault_test)

    scoreboard_t scoreboard;

    function new(string name = "fifo_uvm_scoreboard_fault_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        scoreboard = scoreboard_t::type_id::create("scoreboard", this);
        if (scoreboard == null) begin
            `uvm_fatal("FIFO_SCB_FAULT_FACTORY",
                       "fault test factory returned a null scoreboard")
        end
    endfunction

    function item_t make_observed(
        input string                   name,
        input longint unsigned         transaction_id,
        input bit                      wr_en,
        input bit [DATA_WIDTH-1:0]     wr_data,
        input bit                      rd_en,
        input logic [DATA_WIDTH-1:0]   rd_data,
        input int unsigned             data_count,
        input logic                    empty,
        input logic                    full
    );
        item_t observed_tx;

        observed_tx = item_t::type_id::create(name);
        if (observed_tx == null) begin
            `uvm_fatal("FIFO_SCB_FAULT_ITEM",
                       "fault test factory returned a null transaction")
            return null;
        end

        observed_tx.transaction_id = transaction_id;
        observed_tx.wr_en          = wr_en;
        observed_tx.wr_data        = wr_data;
        observed_tx.rd_en          = rd_en;
        observed_tx.rd_data        = rd_data;
        observed_tx.data_count     = COUNT_WIDTH'(data_count);
        observed_tx.empty          = empty;
        observed_tx.full           = full;
        observed_tx.sampled        = 1'b1;

        return observed_tx;
    endfunction

    virtual task run_phase(uvm_phase phase);
        item_t observed_tx;

        phase.raise_objection(this, "FIFO UVM scoreboard fault injection started");

        if (scoreboard.reference_model == null) begin
            `uvm_fatal("FIFO_SCB_FAULT_NO_REF",
                       "fault test scoreboard did not build its reference model")
            return;
        end

        observed_tx = make_observed("correct_write_a5",
                                    64'd1, 1, 8'hA5, 0,
                                    8'h00, 1, 0, 0);
        scoreboard.write(observed_tx);

        observed_tx = make_observed("bad_transaction_id",
                                    64'd99, 1, 8'h3C, 0,
                                    8'h00, 2, 0, 0);
        scoreboard.write(observed_tx);

        observed_tx = make_observed("bad_sampled",
                                    64'd3, 0, 8'h00, 1,
                                    8'hA5, 1, 0, 0);
        observed_tx.sampled = 1'b0;
        scoreboard.write(observed_tx);

        observed_tx = make_observed("bad_rd_data",
                                    64'd4, 1, 8'h7E, 1,
                                    8'hFF, 1, 0, 0);
        scoreboard.write(observed_tx);

        observed_tx = make_observed("bad_data_count",
                                    64'd5, 1, 8'h55, 0,
                                    8'h3C, 3, 0, 0);
        scoreboard.write(observed_tx);

        observed_tx = make_observed("bad_empty",
                                    64'd6, 0, 8'h00, 1,
                                    8'h7E, 1, 1, 0);
        scoreboard.write(observed_tx);

        observed_tx = make_observed("bad_full",
                                    64'd7, 1, 8'h11, 0,
                                    8'h7E, 2, 0, 1);
        scoreboard.write(observed_tx);

        if ((scoreboard.compared_count != 7) ||
            (scoreboard.pass_count     != 1) ||
            (scoreboard.error_count    != 6) ||
            (scoreboard.field_mismatch_count() != 6) ||
            (scoreboard.transaction_id_mismatch_count != 1) ||
            (scoreboard.sampled_mismatch_count        != 1) ||
            (scoreboard.rd_data_mismatch_count        != 1) ||
            (scoreboard.data_count_mismatch_count     != 1) ||
            (scoreboard.empty_mismatch_count          != 1) ||
            (scoreboard.full_mismatch_count           != 1) ||
            (scoreboard.reference_model.prediction_count != 7) ||
            (scoreboard.reference_model.queue_size()      != 2)) begin
            `uvm_fatal("FIFO_SCB_FAULT_SUMMARY",
                       $sformatf("fault proof expected compared=7 pass=1 transaction_errors=6 field_errors=6 each_field=1 predicted=7 queue=2; got compared=%0d pass=%0d transaction_errors=%0d field_errors=%0d fields=%0d/%0d/%0d/%0d/%0d/%0d predicted=%0d queue=%0d",
                                 scoreboard.compared_count,
                                 scoreboard.pass_count,
                                 scoreboard.error_count,
                                 scoreboard.field_mismatch_count(),
                                 scoreboard.transaction_id_mismatch_count,
                                 scoreboard.sampled_mismatch_count,
                                 scoreboard.rd_data_mismatch_count,
                                 scoreboard.data_count_mismatch_count,
                                 scoreboard.empty_mismatch_count,
                                 scoreboard.full_mismatch_count,
                                 scoreboard.reference_model.prediction_count,
                                 scoreboard.reference_model.queue_size()))
            return;
        end

        `uvm_info("FIFO_SCOREBOARD_FAULT_DETECTED",
                  "UVM SCOREBOARD FAULT DETECTED: transaction_id, sampled, rd_data, data_count, empty and full mismatches were each detected exactly once",
                  UVM_NONE)

        phase.drop_objection(this, "FIFO UVM scoreboard fault injection completed");
    endtask

endclass

`endif
