`ifndef FIFO_UVM_COVERAGE_TEST_SV
`define FIFO_UVM_COVERAGE_TEST_SV

class fifo_uvm_coverage_test extends uvm_test;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;
    localparam int EXPECTED_TRANSACTIONS = (2 * DEPTH) + 8;
    typedef fifo_uvm_environment #(DATA_WIDTH, DEPTH)       environment_t;
    typedef fifo_uvm_coverage_sequence #(DATA_WIDTH, DEPTH) sequence_t;

    `uvm_component_utils(fifo_uvm_coverage_test)

    environment_t env;

    function new(string name = "fifo_uvm_coverage_test",
                 uvm_component parent = null);
        super.new(name, parent);
        env = null;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = environment_t::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        sequence_t coverage_seq;

        phase.raise_objection(this, "FIFO UVM directed coverage test started");

        if ((env == null) ||
            (env.agent == null) ||
            (env.agent.sequencer == null) ||
            (env.coverage_collector == null)) begin
            `uvm_fatal("FIFO_COV_HIERARCHY",
                       "coverage test requires active environment and collector")
            return;
        end

        coverage_seq = sequence_t::type_id::create("coverage_seq");
        if (coverage_seq == null) begin
            `uvm_fatal("FIFO_COV_SEQ_NULL",
                       "factory returned a null coverage sequence")
            return;
        end

        coverage_seq.start(env.agent.sequencer);
        env.coverage_collector.report_coverage();

        if ((coverage_seq.produced_count                 != EXPECTED_TRANSACTIONS) ||
            (env.agent.driver.driven_count               != EXPECTED_TRANSACTIONS) ||
            (env.agent.monitor.observed_count            != EXPECTED_TRANSACTIONS) ||
            (env.scoreboard.compared_count               != EXPECTED_TRANSACTIONS) ||
            (env.scoreboard.pass_count                   != EXPECTED_TRANSACTIONS) ||
            (env.scoreboard.error_count                  != 0) ||
            (env.scoreboard.field_mismatch_count()       != 0) ||
            (env.scoreboard.reference_model.prediction_count != EXPECTED_TRANSACTIONS) ||
            (env.scoreboard.reference_model.queue_size() != 0) ||
            (env.coverage_collector.received_count       != EXPECTED_TRANSACTIONS) ||
            (env.coverage_collector.sample_count         != EXPECTED_TRANSACTIONS) ||
            (env.coverage_collector.error_count          != 0) ||
            (env.coverage_collector.operation_state_hit_total() != EXPECTED_TRANSACTIONS) ||
            (env.coverage_collector.count_after_hit_total()     != EXPECTED_TRANSACTIONS) ||
            (env.coverage_collector.operation_state_hits[0][0] != 2) ||
            (env.coverage_collector.operation_state_hits[0][1] != 4) ||
            (env.coverage_collector.operation_state_hits[0][2] != 1) ||
            (env.coverage_collector.operation_state_hits[1][0] != 1) ||
            (env.coverage_collector.operation_state_hits[1][1] != 4) ||
            (env.coverage_collector.operation_state_hits[1][2] != 1) ||
            (env.coverage_collector.operation_state_hits[2][0] != 1) ||
            (env.coverage_collector.operation_state_hits[2][1] != 1) ||
            (env.coverage_collector.operation_state_hits[2][2] != 1) ||
            (env.coverage_collector.count_after_hits[0] != 4) ||
            (env.coverage_collector.count_after_hits[1] != 4) ||
            (env.coverage_collector.count_after_hits[2] != 2) ||
            (env.coverage_collector.count_after_hits[3] != 3) ||
            (env.coverage_collector.count_after_hits[4] != 3) ||
            (env.coverage_collector.coverage_percent() < 99.99) ||
            (!env.coverage_collector.all_goals_hit())) begin
            `uvm_fatal("FIFO_COV_SUMMARY",
                       $sformatf("directed coverage failed: expected=%0d produced=%0d driven=%0d observed=%0d compared=%0d passed=%0d predicted=%0d scoreboard_errors=%0d field_errors=%0d coverage_received/samples=%0d/%0d coverage_closed=%0b coverage_percent=%0.2f coverage_errors=%0d operation_hits=%0d count_hits=%0d queue=%0d",
                                 EXPECTED_TRANSACTIONS,
                                 coverage_seq.produced_count,
                                 env.agent.driver.driven_count,
                                 env.agent.monitor.observed_count,
                                 env.scoreboard.compared_count,
                                 env.scoreboard.pass_count,
                                 env.scoreboard.reference_model.prediction_count,
                                 env.scoreboard.error_count,
                                 env.scoreboard.field_mismatch_count(),
                                 env.coverage_collector.received_count,
                                 env.coverage_collector.sample_count,
                                 env.coverage_collector.all_goals_hit(),
                                 env.coverage_collector.coverage_percent(),
                                 env.coverage_collector.error_count,
                                 env.coverage_collector.operation_state_hit_total(),
                                 env.coverage_collector.count_after_hit_total(),
                                 env.scoreboard.reference_model.queue_size()))
            return;
        end

        `uvm_info("FIFO_COVERAGE_PASS",
                  $sformatf("UVM COVERAGE PASS: %0d directed transactions closed all operation/state/count goals",
                            EXPECTED_TRANSACTIONS),
                  UVM_NONE)

        phase.drop_objection(this, "FIFO UVM directed coverage test completed");
    endtask

endclass

class fifo_uvm_random_test extends uvm_test;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;
    typedef fifo_uvm_environment #(DATA_WIDTH, DEPTH)    environment_t;
    typedef fifo_uvm_random_sequence #(DATA_WIDTH, DEPTH) sequence_t;

    `uvm_component_utils(fifo_uvm_random_test)

    environment_t env;

    function new(string name = "fifo_uvm_random_test",
                 uvm_component parent = null);
        super.new(name, parent);
        env = null;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = environment_t::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        sequence_t random_seq;
        int unsigned expected_transactions;

        phase.raise_objection(this, "FIFO UVM constrained-random test started");

        if ((env == null) ||
            (env.agent == null) ||
            (env.agent.sequencer == null) ||
            (env.coverage_collector == null)) begin
            `uvm_fatal("FIFO_RAND_HIERARCHY",
                       "random test requires active environment and collector")
            return;
        end

        random_seq = sequence_t::type_id::create("random_seq");
        if (random_seq == null) begin
            `uvm_fatal("FIFO_RAND_SEQ_NULL",
                       "factory returned a null random sequence")
            return;
        end

        random_seq.start(env.agent.sequencer);
        expected_transactions = random_seq.random_transaction_count + DEPTH;
        env.coverage_collector.report_coverage();

        if ((random_seq.produced_count                    != expected_transactions) ||
            (random_seq.randomized_count                  != random_seq.random_transaction_count) ||
            (random_seq.drain_count                       != DEPTH) ||
            (random_seq.random_operation_count()          != random_seq.random_transaction_count) ||
            (random_seq.randomization_error_count         != 0) ||
            (env.agent.driver.driven_count                != expected_transactions) ||
            (env.agent.monitor.observed_count             != expected_transactions) ||
            (env.scoreboard.compared_count                != expected_transactions) ||
            (env.scoreboard.pass_count                    != expected_transactions) ||
            (env.scoreboard.error_count                   != 0) ||
            (env.scoreboard.field_mismatch_count()        != 0) ||
            (env.scoreboard.reference_model.prediction_count != expected_transactions) ||
            (env.scoreboard.reference_model.queue_size()  != 0) ||
            (env.coverage_collector.received_count        != expected_transactions) ||
            (env.coverage_collector.sample_count          != expected_transactions) ||
            (env.coverage_collector.error_count           != 0) ||
            (env.coverage_collector.operation_state_hit_total() != expected_transactions) ||
            (env.coverage_collector.count_after_hit_total()     != expected_transactions) ||
            (env.coverage_collector.coverage_percent()    < 99.99) ||
            (!env.coverage_collector.all_goals_hit())) begin
            `uvm_fatal("FIFO_RAND_SUMMARY",
                       $sformatf("random test failed: random=%0d total=%0d produced=%0d randomized=%0d drain=%0d operation_sum=%0d driven=%0d observed=%0d compared=%0d passed=%0d predicted=%0d scoreboard_errors=%0d field_errors=%0d coverage_received/samples=%0d/%0d coverage_closed=%0b coverage_percent=%0.2f coverage_errors=%0d operation_hits=%0d count_hits=%0d queue=%0d randomization_errors=%0d",
                                 random_seq.random_transaction_count,
                                 expected_transactions,
                                 random_seq.produced_count,
                                 random_seq.randomized_count,
                                 random_seq.drain_count,
                                 random_seq.random_operation_count(),
                                 env.agent.driver.driven_count,
                                 env.agent.monitor.observed_count,
                                 env.scoreboard.compared_count,
                                 env.scoreboard.pass_count,
                                 env.scoreboard.reference_model.prediction_count,
                                 env.scoreboard.error_count,
                                 env.scoreboard.field_mismatch_count(),
                                 env.coverage_collector.received_count,
                                 env.coverage_collector.sample_count,
                                 env.coverage_collector.all_goals_hit(),
                                 env.coverage_collector.coverage_percent(),
                                 env.coverage_collector.error_count,
                                 env.coverage_collector.operation_state_hit_total(),
                                 env.coverage_collector.count_after_hit_total(),
                                 env.scoreboard.reference_model.queue_size(),
                                 random_seq.randomization_error_count))
            return;
        end

        `uvm_info("FIFO_RANDOM_PASS",
                  $sformatf("UVM RANDOM TEST PASS: random=%0d drain=%0d total=%0d read=%0d write=%0d simultaneous=%0d digest=%016h",
                            random_seq.random_transaction_count,
                            DEPTH,
                            expected_transactions,
                            random_seq.random_read_count,
                            random_seq.random_write_count,
                            random_seq.random_simultaneous_count,
                            random_seq.request_digest),
                  UVM_NONE)

        phase.drop_objection(this, "FIFO UVM constrained-random test completed");
    endtask

endclass

class fifo_uvm_coverage_fault_test extends uvm_test;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;
    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);
    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;
    typedef fifo_uvm_coverage #(DATA_WIDTH, DEPTH)      coverage_t;

    `uvm_component_utils(fifo_uvm_coverage_fault_test)

    coverage_t collector;

    function new(string name = "fifo_uvm_coverage_fault_test",
                 uvm_component parent = null);
        super.new(name, parent);
        collector = null;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        collector = coverage_t::type_id::create("collector", this);
        if (collector == null) begin
            `uvm_fatal("FIFO_COV_FAULT_BUILD",
                       "coverage fault test could not create collector")
        end
    endfunction

    function item_t make_sample(string item_name,
                                longint unsigned transaction_id,
                                bit wr_en,
                                bit rd_en,
                                int unsigned count_after,
                                bit sampled);
        item_t sample_tx;

        sample_tx = item_t::type_id::create(item_name);
        if (sample_tx == null) begin
            `uvm_fatal("FIFO_COV_FAULT_ITEM",
                       "coverage fault test could not create sequence item")
            return null;
        end

        sample_tx.transaction_id = transaction_id;
        sample_tx.wr_en           = wr_en;
        sample_tx.wr_data         = DATA_WIDTH'(8'hA5);
        sample_tx.rd_en           = rd_en;
        sample_tx.rd_data         = '0;
        sample_tx.empty           = (count_after == 0);
        sample_tx.full            = (count_after == DEPTH);
        sample_tx.data_count      = COUNT_WIDTH'(count_after);
        sample_tx.sampled         = sampled;
        return sample_tx;
    endfunction

    virtual task run_phase(uvm_phase phase);
        item_t sample_tx;

        phase.raise_objection(this, "FIFO UVM coverage fault test started");

        collector.write(null);

        sample_tx = make_sample("valid_write_empty", 1, 1'b1, 1'b0, 1, 1'b1);
        collector.write(sample_tx);

        sample_tx = make_sample("invalid_unsampled", 2, 1'b0, 1'b1, 0, 1'b0);
        collector.write(sample_tx);

        sample_tx = make_sample("invalid_idle", 3, 1'b0, 1'b0, 1, 1'b1);
        collector.write(sample_tx);

        sample_tx = make_sample("invalid_out_of_range", 4, 1'b0, 1'b1,
                                DEPTH + 1, 1'b1);
        collector.write(sample_tx);

        sample_tx = make_sample("valid_write_middle", 5, 1'b1, 1'b0, 2, 1'b1);
        collector.write(sample_tx);
        collector.report_coverage();

        if ((collector.received_count != 6) ||
            (collector.sample_count != 2) ||
            (collector.error_count != 4) ||
            (collector.count_before != 2) ||
            (collector.operation_state_hit_total() != 2) ||
            (collector.count_after_hit_total() != 2) ||
            (collector.operation_state_hits[1][0] != 1) ||
            (collector.operation_state_hits[1][1] != 1) ||
            (collector.count_after_hits[1] != 1) ||
            (collector.count_after_hits[2] != 1) ||
            collector.all_goals_hit()) begin
            `uvm_fatal("FIFO_COV_FAULT_SUMMARY",
                       $sformatf("coverage rejection proof failed: received=%0d samples=%0d errors=%0d count_before=%0d operation_hits=%0d count_hits=%0d write_empty=%0d write_middle=%0d count1=%0d count2=%0d goals_closed=%0b",
                                 collector.received_count,
                                 collector.sample_count,
                                 collector.error_count,
                                 collector.count_before,
                                 collector.operation_state_hit_total(),
                                 collector.count_after_hit_total(),
                                 collector.operation_state_hits[1][0],
                                 collector.operation_state_hits[1][1],
                                 collector.count_after_hits[1],
                                 collector.count_after_hits[2],
                                 collector.all_goals_hit()))
        end

        `uvm_info("FIFO_COVERAGE_FAULT_DETECTED",
                  "UVM COVERAGE FAULT DETECTED: null, unsampled, idle, and out-of-range inputs were rejected without polluting valid coverage state",
                  UVM_NONE)

        phase.drop_objection(this, "FIFO UVM coverage fault test completed");
    endtask

endclass

`endif
