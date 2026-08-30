`ifndef FIFO_UVM_ENVIRONMENT_SV
`define FIFO_UVM_ENVIRONMENT_SV

// Environment 组装 agent、scoreboard 和 coverage collector，形成完整验证闭环。
class fifo_uvm_environment #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) extends uvm_env;

    typedef fifo_uvm_agent #(DATA_WIDTH, DEPTH)      agent_t;
    typedef fifo_uvm_scoreboard #(DATA_WIDTH, DEPTH) scoreboard_t;
    typedef fifo_uvm_coverage #(DATA_WIDTH, DEPTH)   coverage_t;

    `uvm_component_param_utils(fifo_uvm_environment #(DATA_WIDTH, DEPTH))

    agent_t      agent;
    scoreboard_t scoreboard;
    coverage_t   coverage_collector;

    function new(string name = "fifo_uvm_environment",
                 uvm_component parent = null);
        super.new(name, parent);
        agent              = null;
        scoreboard         = null;
        coverage_collector = null;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent      = agent_t::type_id::create("agent", this);
        scoreboard = scoreboard_t::type_id::create("scoreboard", this);
        coverage_collector = coverage_t::type_id::create(
            "coverage_collector",
            this
        );

        if ((agent == null) ||
            (scoreboard == null) ||
            (coverage_collector == null)) begin
            `uvm_fatal("FIFO_ENV_BUILD",
                       "FIFO environment requires agent, scoreboard, and coverage collector")
            return;
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // monitor 的同一份广播同时送往正确性检查和覆盖率统计。
        agent.observed_ap.connect(scoreboard.analysis_export);

        agent.observed_ap.connect(coverage_collector.analysis_export);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);

        if ((agent == null) ||
            (scoreboard == null) ||
            (coverage_collector == null)) begin
            `uvm_fatal("FIFO_ENV_ELAB_COMPONENT",
                       "FIFO environment hierarchy is incomplete after elaboration")
        end

        if (agent.observed_ap.size() < 2) begin
            `uvm_fatal("FIFO_ENV_SUBSCRIBERS",
                       $sformatf("environment expected at least scoreboard and coverage subscribers, got %0d",
                                 agent.observed_ap.size()))
        end
    endfunction

endclass

`endif
