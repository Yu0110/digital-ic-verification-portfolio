`ifndef FIFO_UVM_AGENT_SV
`define FIFO_UVM_AGENT_SV

// Agent 封装 FIFO 协议相关组件。
// 主动模式包含 sequencer、driver、monitor；被动模式只保留 monitor。
class fifo_uvm_agent #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) extends uvm_agent;

    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;
    typedef fifo_uvm_sequencer #(DATA_WIDTH, DEPTH)     sequencer_t;
    typedef fifo_uvm_driver #(DATA_WIDTH, DEPTH)        driver_t;
    typedef fifo_uvm_monitor #(DATA_WIDTH, DEPTH)       monitor_t;

    `uvm_component_param_utils(fifo_uvm_agent #(DATA_WIDTH, DEPTH))

    // sequencer 和 driver 只在主动模式创建，monitor 在两种模式下都存在。
    sequencer_t sequencer;
    driver_t    driver;

    monitor_t monitor;

    uvm_analysis_port #(item_t) observed_ap;

    function new(string name = "fifo_uvm_agent",
                 uvm_component parent = null);
        super.new(name, parent);

        sequencer   = null;
        driver      = null;
        monitor     = null;
        observed_ap = new("observed_ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // 监视能力与是否主动驱动无关，因此始终创建 monitor。
        monitor = monitor_t::type_id::create("monitor", this);
        if (monitor == null) begin
            `uvm_fatal("FIFO_AGENT_NO_MON",
                       "FIFO agent could not create its monitor")
            return;
        end

        // 主动 agent 负责产生并驱动激励，被动 agent 只观察已有总线活动。
        if (get_is_active() == UVM_ACTIVE) begin
            sequencer = sequencer_t::type_id::create("sequencer", this);
            driver    = driver_t::type_id::create("driver", this);

            if ((sequencer == null) || (driver == null)) begin
                `uvm_fatal("FIFO_AGENT_ACTIVE_BUILD",
                           "active FIFO agent requires both sequencer and driver")
                return;
            end

            `uvm_info("FIFO_AGENT_MODE",
                      "FIFO agent built in UVM_ACTIVE mode",
                      UVM_LOW)
        end else begin
            `uvm_info("FIFO_AGENT_MODE",
                      "FIFO agent built in UVM_PASSIVE mode",
                      UVM_LOW)
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // 事务驱动通路只在主动模式连接。
        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end

        // monitor 的采样结果经 agent 公共 analysis port 向环境继续广播。
        monitor.observed_ap.connect(observed_ap);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        int public_subscriber_count;
        int monitor_subscriber_count;

        super.end_of_elaboration_phase(phase);

        if (monitor == null) begin
            `uvm_fatal("FIFO_AGENT_ELAB_MON",
                       "FIFO agent requires a monitor in both active and passive modes")
        end

        if (get_is_active() == UVM_ACTIVE) begin
            if ((sequencer == null) || (driver == null)) begin
                `uvm_fatal("FIFO_AGENT_ELAB_ACTIVE",
                           "active FIFO agent lost its sequencer or driver")
            end

            if (driver.seq_item_port.size() != 1) begin
                `uvm_fatal("FIFO_AGENT_SEQ_CONNECTION",
                           $sformatf("active driver expected one sequencer connection, got %0d",
                                     driver.seq_item_port.size()))
            end
        end else begin
            if ((sequencer != null) || (driver != null)) begin
                `uvm_fatal("FIFO_AGENT_ELAB_PASSIVE",
                           "passive FIFO agent must not contain sequencer or driver")
            end
        end

        // 展开结束后检查连接数量，避免 analysis port 静默丢失订阅者。
        public_subscriber_count  = observed_ap.size();
        monitor_subscriber_count = monitor.observed_ap.size();

        if (public_subscriber_count == 0) begin
            `uvm_fatal("FIFO_AGENT_NO_SUBSCRIBER",
                       "FIFO agent public analysis port has no final subscriber")
        end

        if (monitor_subscriber_count != public_subscriber_count) begin
            `uvm_fatal("FIFO_AGENT_BROADCAST_PATH",
                       $sformatf("monitor/public analysis paths resolve to different subscriber counts: %0d/%0d",
                                 monitor_subscriber_count,
                                 public_subscriber_count))
        end
    endfunction

endclass

`endif
