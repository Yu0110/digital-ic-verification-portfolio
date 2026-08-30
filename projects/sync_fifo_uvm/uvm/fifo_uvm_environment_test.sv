`ifndef FIFO_UVM_ENVIRONMENT_TEST_SV
`define FIFO_UVM_ENVIRONMENT_TEST_SV

class fifo_uvm_environment_audit_tap #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) extends uvm_subscriber #(fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH));

    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;

    `uvm_component_param_utils(
        fifo_uvm_environment_audit_tap #(DATA_WIDTH, DEPTH)
    )

    int unsigned received_count;
    item_t       last_tx;

    function new(string name = "fifo_uvm_environment_audit_tap",
                 uvm_component parent = null);
        super.new(name, parent);
        received_count = 0;
        last_tx        = null;
    endfunction

    virtual function void write(item_t observed_tx);
        if (observed_tx == null) begin
            `uvm_fatal("FIFO_ENV_TAP_NULL",
                       "environment audit tap received a null transaction")
        end

        received_count++;
        last_tx = observed_tx;
    endfunction

endclass

class fifo_uvm_environment_test extends uvm_test;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;
    typedef fifo_uvm_environment #(DATA_WIDTH, DEPTH)    environment_t;
    typedef fifo_uvm_basic_sequence #(DATA_WIDTH, DEPTH) sequence_t;
    typedef fifo_uvm_environment_audit_tap #(
        DATA_WIDTH,
        DEPTH
    ) audit_tap_t;

    `uvm_component_utils(fifo_uvm_environment_test)

    environment_t env;
    audit_tap_t   audit_tap;

    function new(string name = "fifo_uvm_environment_test",
                 uvm_component parent = null);
        super.new(name, parent);
        env       = null;
        audit_tap = null;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env = environment_t::type_id::create("env", this);
        audit_tap = audit_tap_t::type_id::create("audit_tap", this);

        if ((env == null) || (audit_tap == null)) begin
            `uvm_fatal("FIFO_ENV_TEST_BUILD",
                       "test could not create the FIFO environment and audit tap")
            return;
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        env.agent.observed_ap.connect(audit_tap.analysis_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
        sequence_t basic_seq;

        phase.raise_objection(this, "FIFO UVM environment test started");

        if ((env.agent == null) ||
            (env.scoreboard == null) ||
            (env.agent.get_is_active() != UVM_ACTIVE) ||
            (env.agent.sequencer == null) ||
            (env.agent.driver == null) ||
            (env.agent.monitor == null) ||
            (env.coverage_collector == null) ||
            (audit_tap == null) ||
            (env.agent.driver.seq_item_port.size() != 1) ||
            (env.agent.observed_ap.size() != 3) ||
            (env.agent.monitor.observed_ap.size() != 3)) begin
            `uvm_fatal("FIFO_ENV_HIERARCHY",
                       $sformatf("active hierarchy/topology is incomplete: seq_links=%0d public_subscribers=%0d monitor_subscribers=%0d",
                                 (env.agent.driver == null) ? -1 : env.agent.driver.seq_item_port.size(),
                                 env.agent.observed_ap.size(),
                                 (env.agent.monitor == null) ? -1 : env.agent.monitor.observed_ap.size()))
            return;
        end

        basic_seq = sequence_t::type_id::create("basic_seq");
        if (basic_seq == null) begin
            `uvm_fatal("FIFO_ENV_SEQ_NULL",
                       "factory returned a null basic sequence")
            return;
        end

        basic_seq.start(env.agent.sequencer);

        if ((basic_seq.produced_count                         != 5) ||
            (env.agent.driver.driven_count                    != 5) ||
            (env.agent.monitor.observed_count                 != 5) ||
            (env.scoreboard.compared_count                    != 5) ||
            (env.scoreboard.pass_count                        != 5) ||
            (env.scoreboard.error_count                       != 0) ||
            (env.scoreboard.field_mismatch_count()            != 0) ||
            (env.coverage_collector.sample_count              != 5) ||
            (env.coverage_collector.error_count               != 0) ||
            (audit_tap.received_count                         != 5) ||
            (env.scoreboard.reference_model.prediction_count != 5) ||
            (env.scoreboard.reference_model.queue_size()      != 0) ||
            (env.scoreboard.last_actual_tx             == null) ||
            (env.scoreboard.last_expected_tx           == null) ||
            (audit_tap.last_tx                         == null) ||
            (audit_tap.last_tx                         != env.scoreboard.last_actual_tx) ||
            (env.scoreboard.last_actual_tx.rd_data     !== 8'h7E) ||
            (env.scoreboard.last_actual_tx.data_count  !== '0) ||
            (env.scoreboard.last_actual_tx.empty       !== 1'b1) ||
            (env.scoreboard.last_actual_tx.full        !== 1'b0)) begin
            `uvm_fatal("FIFO_ENV_SUMMARY",
                       $sformatf("environment expected produced/driven/observed/compared/pass/predicted/tap=5, errors=0, queue=0; got %0d/%0d/%0d/%0d/%0d/%0d/%0d, scoreboard_errors=%0d field_errors=%0d coverage_errors=%0d queue=%0d",
                                 basic_seq.produced_count,
                                 env.agent.driver.driven_count,
                                 env.agent.monitor.observed_count,
                                 env.scoreboard.compared_count,
                                 env.scoreboard.pass_count,
                                 env.scoreboard.reference_model.prediction_count,
                                 audit_tap.received_count,
                                 env.scoreboard.error_count,
                                 env.scoreboard.field_mismatch_count(),
                                 env.coverage_collector.error_count,
                                 env.scoreboard.reference_model.queue_size()))
            return;
        end

        `uvm_info("FIFO_ENVIRONMENT_PASS",
                  "UVM ENVIRONMENT PASS: active agent drove 5 transactions and broadcast all 5 to scoreboard, coverage, and audit tap",
                  UVM_NONE)

        phase.drop_objection(this, "FIFO UVM environment test completed");
    endtask

endclass

class fifo_uvm_passive_agent_test extends uvm_test;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;
    typedef fifo_uvm_environment #(DATA_WIDTH, DEPTH) environment_t;
    typedef virtual fifo_if #(DATA_WIDTH, DEPTH)      virtual_if_t;
    localparam bit [DATA_WIDTH-1:0] DATA_A5 = DATA_WIDTH'(8'hA5);

    `uvm_component_utils(fifo_uvm_passive_agent_test)

    environment_t env;
    virtual_if_t  vif;

    function new(string name = "fifo_uvm_passive_agent_test",
                 uvm_component parent = null);
        super.new(name, parent);
        env = null;
        vif = null;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        uvm_config_db #(uvm_active_passive_enum)::set(
            this,
            "env.agent",
            "is_active",
            UVM_PASSIVE
        );

        env = environment_t::type_id::create("env", this);
        if (env == null) begin
            `uvm_fatal("FIFO_PASSIVE_TEST_BUILD",
                       "test could not create the passive FIFO environment")
            return;
        end

        if (!uvm_config_db #(virtual_if_t)::get(this, "", "vif", vif)) begin
            `uvm_fatal("FIFO_PASSIVE_NO_VIF",
                       "passive environment test could not get virtual interface 'vif'")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "FIFO passive agent test started");

        vif.wr_en   <= 1'b0;
        vif.wr_data <= '0;
        vif.rd_en   <= 1'b0;
        #1ns;
        vif.rst_n   <= 1'b0;

        @(vif.drv_cb);
        vif.rst_n <= 1'b1;

        @(vif.drv_cb);
        vif.drv_cb.wr_en   <= 1'b1;
        vif.drv_cb.wr_data <= DATA_A5;
        vif.drv_cb.rd_en   <= 1'b0;

        @(vif.drv_cb);
        vif.drv_cb.wr_en   <= 1'b0;
        vif.drv_cb.wr_data <= '0;
        vif.drv_cb.rd_en   <= 1'b0;

        @(vif.drv_cb);
        vif.drv_cb.wr_en   <= 1'b0;
        vif.drv_cb.wr_data <= '0;
        vif.drv_cb.rd_en   <= 1'b1;

        @(vif.drv_cb);
        vif.drv_cb.wr_en   <= 1'b0;
        vif.drv_cb.wr_data <= '0;
        vif.drv_cb.rd_en   <= 1'b0;
        #1ns;

        if ((env.agent == null) ||
            (env.scoreboard == null) ||
            (env.agent.get_is_active() != UVM_PASSIVE) ||
            (env.agent.sequencer != null) ||
            (env.agent.driver != null) ||
            (env.agent.monitor == null) ||
            (env.coverage_collector == null) ||
            (env.agent.observed_ap.size() != 2) ||
            (env.agent.monitor.observed_ap.size() != 2) ||
            (env.agent.monitor.observed_count != 2) ||
            (env.scoreboard.compared_count != 2) ||
            (env.scoreboard.pass_count != 2) ||
            (env.scoreboard.error_count != 0) ||
            (env.scoreboard.field_mismatch_count() != 0) ||
            (env.scoreboard.reference_model.prediction_count != 2) ||
            (env.scoreboard.reference_model.queue_size() != 0) ||
            (env.coverage_collector.sample_count != 2) ||
            (env.coverage_collector.error_count != 0) ||
            (env.scoreboard.last_actual_tx == null) ||
            (env.scoreboard.last_actual_tx.rd_data !== DATA_A5) ||
            (env.scoreboard.last_actual_tx.data_count !== '0) ||
            (env.scoreboard.last_actual_tx.empty !== 1'b1) ||
            (env.scoreboard.last_actual_tx.full !== 1'b0) ||
            (vif.wr_en !== 1'b0) ||
            (vif.rd_en !== 1'b0)) begin
            `uvm_fatal("FIFO_PASSIVE_HIERARCHY",
                       $sformatf("passive environment expected two externally driven and checked transactions; observed/compared/pass/predicted/coverage=%0d/%0d/%0d/%0d/%0d errors=%0d field_errors=%0d coverage_errors=%0d",
                                 (env.agent.monitor == null) ? 0 : env.agent.monitor.observed_count,
                                 env.scoreboard.compared_count,
                                 env.scoreboard.pass_count,
                                 env.scoreboard.reference_model.prediction_count,
                                 env.coverage_collector.sample_count,
                                 env.scoreboard.error_count,
                                 env.scoreboard.field_mismatch_count(),
                                 env.coverage_collector.error_count))
            return;
        end

        `uvm_info("FIFO_PASSIVE_AGENT_PASS",
                  "UVM PASSIVE AGENT PASS: no sequencer/driver was created, while two external transactions were observed, checked, and covered",
                  UVM_NONE)

        phase.drop_objection(this, "FIFO passive agent test completed");
    endtask

endclass

class fifo_uvm_broken_environment #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) extends fifo_uvm_environment #(DATA_WIDTH, DEPTH);

    `uvm_component_param_utils(
        fifo_uvm_broken_environment #(DATA_WIDTH, DEPTH)
    )

    function new(string name = "fifo_uvm_broken_environment",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        agent.observed_ap.connect(scoreboard.analysis_export);
    endfunction

endclass

class fifo_uvm_environment_topology_fault_test extends uvm_test;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;
    typedef fifo_uvm_broken_environment #(
        DATA_WIDTH,
        DEPTH
    ) broken_environment_t;

    `uvm_component_utils(fifo_uvm_environment_topology_fault_test)

    broken_environment_t broken_env;

    function new(string name = "fifo_uvm_environment_topology_fault_test",
                 uvm_component parent = null);
        super.new(name, parent);
        broken_env = null;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        broken_env = broken_environment_t::type_id::create("broken_env", this);
        if (broken_env == null) begin
            `uvm_fatal("FIFO_ENV_FAULT_BUILD",
                       "fault test could not create the deliberately broken environment")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        `uvm_fatal("FIFO_ENV_FAULT_ESCAPED",
                   "broken environment unexpectedly reached run_phase")
    endtask

endclass

`endif
